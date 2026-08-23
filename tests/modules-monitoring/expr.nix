# Test: Grafana alerting pipeline integrity.
#
# The alerting stack fails silently when broken: a wrong datasource
# reference or an ignored misspelled key produces no eval-time error, only
# missing push notifications on the phone. These checks turn such
# regressions into hard eval failures; the remaining values are snapshotted
# for review of intentional changes.
{flake, ...}: let
  inherit (flake.nixosConfigurations.m920q) config;
  provision = config.services.grafana.provision.alerting;

  homelabGroup = builtins.head (
    builtins.filter (g: g.name == "homelab") provision.rules.settings.groups
  );
  inherit (homelabGroup) rules;

  queryOf = refId: rule:
    builtins.head (builtins.filter (q: q.refId == refId) rule.data);

  contactPoints = provision.contactPoints.settings.contactPoints;
  receiver = builtins.head (builtins.head contactPoints).receivers;
  policy = builtins.head provision.policies.settings.policies;

  # Keys understood by the Grafana provisioning API for alert rules. A key
  # outside this list is silently dropped by Grafana (e.g. snake_case
  # exec_err_state instead of camelCase execErrState), so its intended
  # behavior never takes effect.
  knownRuleKeys = [
    "uid"
    "title"
    "condition"
    "for"
    "noDataState"
    "execErrState"
    "labels"
    "annotations"
    "data"
  ];

  validNoDataStates = ["NoData" "Alerting" "OK"];
  validExecErrStates = ["OK" "Alerting" "Error" "KeepLast"];

  unknownKeys = rule:
    builtins.filter (k: !builtins.elem k knownRuleKeys) (builtins.attrNames rule);

  enabledServices =
    [
      "fritzbox-wan-down"
      "node-exporter-down"
      "postgres-down"
    ]
    ++ (lib.optionals config.modules.system.homelab.nextcloud.enable ["nextcloud-down"])
    ++ (lib.optionals config.modules.system.homelab.immich.enable ["immich-down"])
    ++ (lib.optionals config.modules.system.homelab.adguardhome.enable ["adguard-down"])
    ++ (lib.optionals config.modules.system.homelab.backup.enable ["backup-failed"]);

  inherit (flake.nixosConfigurations.m920q.pkgs) lib;
in
  # Every data query must reference the provisioned Prometheus datasource by
  # its scalar uid. The nested datasource object form does not survive
  # provisioning round-trip and yields "can not get data source by uid" at
  # evaluation time, killing every alert silently.
  assert builtins.all (r: (queryOf "A" r).datasourceUid or "" == "prometheus") rules;
  assert builtins.all (r: (queryOf "A" r).model.expr != "") rules;
  # Unknown keys must fail here, not vanish inside Grafana.
  assert builtins.all (r: unknownKeys r == []) rules;
  # State values must be from the sets Grafana actually accepts.
  assert builtins.all (r: builtins.elem r.noDataState validNoDataStates) rules;
  assert builtins.all (r: builtins.elem r.execErrState validExecErrStates) rules;
  # Down-detection relies on firing when data disappears entirely.
  assert builtins.all (r: r.noDataState == "Alerting") rules; {
    rule_count = builtins.length rules;
    expected_rules = enabledServices;
    rules =
      map (r: {
        inherit (r) uid title noDataState execErrState;
        severity = r.labels.severity;
        datasource_uid = (queryOf "A" r).datasourceUid;
        expr = (queryOf "A" r).model.expr;
      })
      rules;
    inherit (homelabGroup) folder;
    inherit (homelabGroup) interval;
    contact_point = {
      inherit ((builtins.head contactPoints)) name;
      inherit (receiver) type;
      url = receiver.settings.url;
      topic_in_payload = builtins.match ".*homelab-alerts.*" receiver.settings.payload.template != null;
      priority_templated = builtins.match ".*priority.*" receiver.settings.payload.template != null;
      disable_resolve_message = receiver.disableResolveMessage;
    };
    policy = {
      inherit (policy) group_by group_wait group_interval repeat_interval;
    };
  }
