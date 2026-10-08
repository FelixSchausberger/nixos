# Test: alerting pipeline integrity.
#
# Prometheus evaluates the alert rules, Alertmanager groups and re-notifies
# them, and alertmanager-ntfy delivers each alert to ntfy. These layers fail
# silently when broken (a missing priority label, a wrong receiver URL, a
# dropped option all still evaluate), so the checks below turn such
# regressions into hard eval failures; the remaining values are snapshotted
# for review of intentional changes.
{flake, ...}: let
  inherit (flake.nixosConfigurations.m920q) config;
  pkgs = flake.nixosConfigurations.m920q.pkgs;
  inherit (pkgs) lib;

  groups = config.modules.system.homelab.monitoring.alerting.ruleGroups;
  rules = builtins.concatMap (g: g.rules) groups;

  # ntfy priority names (docs.ntfy.sh/publish/#message-priority). The delivery
  # bridge reads the priority verbatim from the alert's `priority` label.
  validPriorities = ["urgent" "high" "default" "low" "min"];

  route = config.services.prometheus.alertmanager.configuration.route;
  receivers = config.services.prometheus.alertmanager.configuration.receivers;
  receiver = builtins.head receivers;

  # Prometheus targets Alertmanager; Alertmanager's webhook points at the
  # bridge; the bridge publishes to the local ntfy topic.
  alertmanagerTargets =
    builtins.concatMap (a: builtins.concatMap (s: s.targets) a.static_configs)
    config.services.prometheus.alertmanagers;

  amNtfy = config.services.prometheus.alertmanager-ntfy.settings;
in
  # Every rule needs an expr, a valid ntfy priority, and a host-templated
  # summary so the notification names its source machine.
  assert builtins.length rules > 0;
  assert builtins.all (r: r.expr != "") rules;
  assert builtins.all (r: builtins.elem r.labels.priority validPriorities) rules;
  assert builtins.all (r: lib.hasSuffix "{{ $labels.host }}" r.annotations.summary) rules;
  # Delivery chain is wired end to end.
  assert builtins.elem "127.0.0.1:9093" alertmanagerTargets;
  assert receiver.name == "ntfy";
  assert (builtins.head receiver.webhook_configs).url == "http://127.0.0.1:8000/hook";
  assert amNtfy.ntfy.baseurl == "http://127.0.0.1:2586";
  assert amNtfy.ntfy.notification.topic == "homelab-alerts";
  assert lib.hasInfix "alert.labels.priority" amNtfy.ntfy.notification.priority;
  # The rules are serialized into services.prometheus.rules as one file.
  assert builtins.length config.services.prometheus.rules == 1; {
    rule_count = builtins.length rules;
    rules =
      map (r: {
        inherit (r) alert expr;
        priority = r.labels.priority;
      })
      rules;
    scrape_jobs = map (j: j.job_name) config.services.prometheus.scrapeConfigs;
    # Every scrape target carries a host label so the rule summaries and the
    # notification title can name the machine.
    scrape_hosts =
      lib.sort (a: b: a < b)
      (lib.unique (builtins.concatMap
        (j: builtins.concatMap (s: lib.optional (s.labels ? host) s.labels.host) j.static_configs)
        config.services.prometheus.scrapeConfigs));
    vitals_scrape_enabled =
      builtins.any (j: j.job_name == "vitals") config.services.prometheus.scrapeConfigs;
    dashboard_providers =
      map (p: p.name) config.services.grafana.provision.dashboards.settings.providers;
    alertmanager = {
      alertmanager_targets = alertmanagerTargets;
      route = {
        inherit (route) receiver group_by group_wait group_interval repeat_interval;
      };
      receiver = {
        inherit (receiver) name;
        inherit ((builtins.head receiver.webhook_configs)) url;
        inherit ((builtins.head receiver.webhook_configs)) send_resolved;
      };
    };
    alertmanager_ntfy = {
      topic = amNtfy.ntfy.notification.topic;
      priority = amNtfy.ntfy.notification.priority;
      title = amNtfy.ntfy.notification.templates.title;
      inherit (amNtfy.ntfy.notification.templates) headers;
      inherit (amNtfy.ntfy.notification) tags;
    };
  }
