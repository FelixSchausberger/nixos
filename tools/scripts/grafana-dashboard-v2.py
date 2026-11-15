#!/usr/bin/env python3
"""Convert a classic Grafana dashboard JSON into the v2 resource model.

Grafana 13 stores and exports a dashboard that uses the new layout engine as a
`dashboard.grafana.app/v2` resource. Only the v2 model has auto-grid layouts,
and only auto-grid layouts reflow from one column on a phone to the authored
column count on a desktop. Dashboard files in this repository are provisioned
verbatim, so the converted resource is the committed artifact.

Usage:
    grafana-dashboard-v2.py classic.json > dashboard.json
    grafana-dashboard-v2.py classic.json --output dashboard.json
    grafana-dashboard-v2.py new-classic.json --diff modules/system/homelab/power-dashboard.json

What is preserved: panel queries, field config, panel options, annotations,
template variables, time settings, tags, title and the dashboard UID.

What is translated: every classic `row` panel starts a section, and panels that
shared a `gridPos.y` become one auto-grid row. A section with several lines of
differing width therefore yields several rows, the first carrying the section
title and the rest hidden-header continuations, which keeps the authored
desktop density instead of stretching a two-panel line across a four-panel
track grid. `maxColumnCount` is the line's panel count capped at five, which is
the convention the existing v2 dashboards use.

Anything else aborts with an error instead of being dropped silently: an
unknown panel type, variable type, enum value, a collapsed row, a legacy
string datasource or a dashboard link has no verified mapping yet.
"""

import argparse
import json
import sys

# Classic enum values, from the dashboard schema documentation. Anything not in
# these tables aborts the conversion.
HIDE = {0: "dontHide", 1: "hideLabel", 2: "hideVariable"}
REFRESH = {0: "never", 1: "onDashboardLoad", 2: "onTimeRangeChanged"}
SORT = {
    0: "disabled",
    1: "alphabeticalAsc",
    2: "alphabeticalDesc",
    3: "numericalAsc",
    4: "numericalDesc",
}
CURSOR_SYNC = {0: "Off", 1: "Crosshair", 2: "Tooltip"}

# Grafana's default time-picker intervals, used when the classic dashboard does
# not carry its own list.
AUTO_REFRESH_INTERVALS = [
    "5s",
    "10s",
    "30s",
    "1m",
    "5m",
    "15m",
    "30m",
    "1h",
    "2h",
    "1d",
]

MAX_COLUMNS = 5


class ConversionError(Exception):
    pass


def enum(table, value, what):
    if value is None:
        value = 0
    if value not in table:
        raise ConversionError(f"{what}: no v2 equivalent for {value!r}")
    return table[value]


def variable_option(option):
    option = option or {}
    return {
        "text": option.get("text", ""),
        "value": option.get("value", ""),
    }


def resolve_datasource(datasource, panel_datasource, variable_types, where):
    """Return (uid, plugin_id) for a datasource reference.

    Classic targets often carry only `{uid: "$datasource"}`; the plugin id then
    lives on the panel datasource or on the datasource variable the uid names,
    which is where Grafana resolves it from as well.
    """
    if isinstance(datasource, str):
        raise ConversionError(f"{where}: legacy string datasource {datasource!r}")
    if datasource is None:
        if panel_datasource is None:
            raise ConversionError(f"{where}: query has no datasource")
        return resolve_datasource(panel_datasource, None, variable_types, where)
    uid = datasource.get("uid")
    if not uid:
        raise ConversionError(f"{where}: datasource has no uid, got {datasource!r}")
    plugin = datasource.get("type")
    if not plugin and isinstance(panel_datasource, dict) and panel_datasource.get("uid") == uid:
        plugin = panel_datasource.get("type")
    if not plugin and uid.startswith("$"):
        plugin = variable_types.get(uid[1:])
    if not plugin:
        raise ConversionError(f"{where}: no plugin id for datasource {uid!r}")
    return uid, plugin


def convert_target(target, panel_datasource, variable_types, where):
    uid, plugin = resolve_datasource(
        target.get("datasource"), panel_datasource, variable_types, where
    )
    query = {k: v for k, v in target.items() if k not in ("datasource", "refId", "hide")}
    return {
        "kind": "PanelQuery",
        "spec": {
            "query": {
                "kind": "DataQuery",
                "group": plugin,
                "version": "v0",
                "datasource": {"name": uid},
                "spec": query,
            },
            "refId": target.get("refId", "A"),
            "hidden": bool(target.get("hide", False)),
        },
    }


def query_options(panel):
    """Classic panel-level query settings, mapped like Grafana's converter."""
    options = dict(panel.get("queryOptions") or {})
    for classic, v2 in (
        ("timeFrom", "timeFrom"),
        ("timeShift", "timeShift"),
        ("timeCompare", "timeCompare"),
        ("interval", "interval"),
        ("cacheTimeout", "cacheTimeout"),
    ):
        if panel.get(classic):
            options[v2] = panel[classic]
    if panel.get("maxDataPoints"):
        options["maxDataPoints"] = panel["maxDataPoints"]
    if panel.get("hideTimeOverride"):
        options["hideTimeOverride"] = True
    if panel.get("queryCachingTTL"):
        options["queryCachingTTL"] = int(panel["queryCachingTTL"])
    return options


def convert_panel(panel, variable_types, where):
    if "libraryPanel" in panel:
        raise ConversionError(f"{where}: library panels are not supported")
    if panel.get("repeat"):
        raise ConversionError(f"{where}: repeated panels are not supported")
    if panel.get("links"):
        raise ConversionError(f"{where}: panel data links are not supported")
    panel_type = panel.get("type")
    if not panel_type:
        raise ConversionError(f"{where}: panel has no type")
    panel_id = panel.get("id")
    if not isinstance(panel_id, int):
        raise ConversionError(f"{where}: panel has no numeric id")

    datasource = panel.get("datasource")
    queries = [
        convert_target(
            target, datasource, variable_types, f"{where} query {target.get('refId', '?')}"
        )
        for target in panel.get("targets", [])
    ]

    spec = {
        "id": panel_id,
        "title": panel.get("title", ""),
        "description": panel.get("description", ""),
        "links": [],
        "data": {
            "kind": "QueryGroup",
            "spec": {
                "queries": queries,
                "transformations": panel.get("transformations", []),
                "queryOptions": query_options(panel),
            },
        },
        "vizConfig": {
            "kind": "VizConfig",
            "group": panel_type,
            "version": panel.get("pluginVersion", ""),
            "spec": {
                "options": panel.get("options", {}),
                "fieldConfig": panel.get(
                    "fieldConfig", {"defaults": {}, "overrides": []}
                ),
            },
        },
    }
    if panel.get("transparent"):
        spec["transparent"] = True
    return f"panel-{panel_id}", {"kind": "Panel", "spec": spec}


def row_height(panels):
    # Classic grid rows are 30 px plus margins: h=4 is a stat strip (~130 px),
    # h=8/h=9 a chart (~250-300 px) and h>=10 the tall log panels (~450 px+).
    # Auto-grid rows are 168 / 320 / 512 px respectively.
    tallest = max((panel.get("gridPos") or {}).get("h", 0) for panel in panels)
    if tallest <= 4:
        return "short"
    if tallest <= 9:
        return "standard"
    return "tall"


def convert_layout(panels):
    # Sections mirror the classic `row` panels; lines mirror `gridPos.y`, which
    # is what keeps a four-stat line and a two-chart line on separate grids.
    sections = []
    for panel in panels:
        if panel.get("type") == "row":
            if panel.get("panels"):
                raise ConversionError(
                    f"collapsed row {panel.get('title')!r} is not supported"
                )
            sections.append(
                {
                    "title": panel.get("title", ""),
                    "collapse": bool(panel.get("collapsed", False)),
                    "lines": [],
                }
            )
            continue
        if not sections:
            sections.append({"title": "", "collapse": False, "lines": []})
        y = (panel.get("gridPos") or {}).get("y")
        lines = sections[-1]["lines"]
        if lines and lines[-1]["y"] == y:
            lines[-1]["panels"].append(panel)
        else:
            lines.append({"y": y, "panels": [panel]})

    rows = []
    for section in sections:
        if not section["lines"]:
            raise ConversionError(f"row {section['title']!r} has no panels")
        for index, line in enumerate(section["lines"]):
            items = [
                {
                    "kind": "AutoGridLayoutItem",
                    "spec": {"element": {"kind": "ElementReference", "name": f"panel-{panel['id']}"}},
                }
                for panel in line["panels"]
            ]
            rows.append(
                {
                    "kind": "RowsLayoutRow",
                    "spec": {
                        "title": section["title"] if index == 0 else "",
                        "collapse": section["collapse"] if index == 0 else False,
                        "hideHeader": index > 0 or section["title"] == "",
                        "layout": {
                            "kind": "AutoGridLayout",
                            "spec": {
                                "maxColumnCount": min(len(line["panels"]), MAX_COLUMNS),
                                "columnWidthMode": "narrow",
                                "rowHeightMode": row_height(line["panels"]),
                                "items": items,
                            },
                        },
                    },
                }
            )
    return {"kind": "RowsLayout", "spec": {"rows": rows}}


def convert_variable(variable):
    name = variable.get("name")
    if not name:
        raise ConversionError("template variable has no name")
    kind = variable.get("type")
    common = {
        "name": name,
        "current": variable_option(variable.get("current")),
        "hide": enum(HIDE, variable.get("hide"), f"variable {name} hide"),
        "skipUrlSync": bool(variable.get("skipUrlSync", False)),
    }

    if kind == "datasource":
        return {
            "kind": "DatasourceVariable",
            "spec": {
                **common,
                "pluginId": variable.get("query", ""),
                "refresh": enum(REFRESH, variable.get("refresh"), f"variable {name} refresh"),
                "regex": variable.get("regex", ""),
                "options": [variable_option(option) for option in variable.get("options", [])],
                "multi": bool(variable.get("multi", False)),
                "includeAll": bool(variable.get("includeAll", False)),
                "allowCustomValue": True,
            },
        }

    if kind == "custom":
        # Custom variables carry a comma-separated option list as a plain
        # string, and each option records whether it is selected; both survive
        # in CustomVariableSpec as `query` and `options`.
        return {
            "kind": "CustomVariable",
            "spec": {
                **common,
                "label": variable.get("label", name),
                "description": variable.get("description", ""),
                "query": variable.get("query", ""),
                "options": [
                    {
                        **variable_option(option),
                        "selected": bool(option.get("selected", False)),
                    }
                    for option in variable.get("options", [])
                ],
                "multi": bool(variable.get("multi", False)),
                "includeAll": bool(variable.get("includeAll", False)),
                "allowCustomValue": True,
            },
        }

    if kind == "query":
        uid, plugin = resolve_datasource(
            variable.get("datasource"), None, {}, f"variable {name}"
        )
        query = variable.get("query")
        if isinstance(query, dict):
            spec = {"query": query.get("query", ""), "refId": query.get("refId", f"{name}-variable-query")}
        elif isinstance(query, str):
            spec = {"query": query, "refId": f"{name}-variable-query"}
        else:
            raise ConversionError(f"variable {name}: unsupported query {query!r}")
        return {
            "kind": "QueryVariable",
            "spec": {
                **common,
                "label": variable.get("label", name),
                "refresh": enum(REFRESH, variable.get("refresh"), f"variable {name} refresh"),
                "query": {
                    "kind": "DataQuery",
                    "group": plugin,
                    "version": "v0",
                    "datasource": {"name": uid},
                    "spec": spec,
                },
                "regex": variable.get("regex", ""),
                "regexApplyTo": "value",
                "sort": enum(SORT, variable.get("sort"), f"variable {name} sort"),
                "definition": variable.get("definition", ""),
                "options": [variable_option(option) for option in variable.get("options", [])],
                "multi": bool(variable.get("multi", False)),
                "includeAll": bool(variable.get("includeAll", False)),
                "allowCustomValue": True,
            },
        }

    raise ConversionError(f"variable {name}: unsupported type {kind!r}")


def convert_annotation(annotation):
    datasource = annotation.get("datasource") or {}
    if datasource.get("uid") != "-- Grafana --" and not annotation.get("builtIn"):
        raise ConversionError(
            f"annotation {annotation.get('name')!r}: only the built-in datasource is supported"
        )
    return {
        "kind": "AnnotationQuery",
        "spec": {
            "query": {
                "kind": "DataQuery",
                "group": "grafana",
                "version": "v0",
                "datasource": {"name": "grafana"},
                "spec": {
                    "limit": 100,
                    "matchAny": False,
                    "tags": [],
                    "type": "dashboard",
                },
            },
            "enable": bool(annotation.get("enable", True)),
            "hide": bool(annotation.get("hide", False)),
            "iconColor": annotation.get("iconColor", ""),
            "name": annotation.get("name", "Annotations & Alerts"),
            "builtIn": bool(annotation.get("builtIn", True)),
        },
    }


def convert(dashboard, uid_override):
    uid = uid_override or dashboard.get("uid")
    if not uid:
        raise ConversionError("dashboard has no uid")
    title = dashboard.get("title")
    if not title:
        raise ConversionError("dashboard has no title")
    if dashboard.get("links"):
        raise ConversionError("dashboard links are not supported")

    variables = (dashboard.get("templating") or {}).get("list", [])
    # `$datasource` style references carry no plugin id; the datasource
    # variable that declares the name is the only place it is recorded.
    variable_types = {
        variable["name"]: variable.get("query", "")
        for variable in variables
        if variable.get("type") == "datasource" and variable.get("name")
    }

    panels = dashboard.get("panels")
    if panels is None:
        raise ConversionError("dashboard has no panels array")

    elements = {}
    for index, panel in enumerate(panels):
        if panel.get("type") == "row":
            continue
        key, element = convert_panel(panel, variable_types, f"panel {index}")
        if key in elements:
            raise ConversionError(f"duplicate panel id in {key}")
        elements[key] = element

    time = dashboard.get("time") or {}
    timepicker = dashboard.get("timepicker") or {}

    return {
        "apiVersion": "dashboard.grafana.app/v2",
        "kind": "Dashboard",
        "metadata": {"name": uid},
        "spec": {
            "annotations": [
                convert_annotation(annotation)
                for annotation in (dashboard.get("annotations") or {}).get("list", [])
            ],
            "cursorSync": enum(CURSOR_SYNC, dashboard.get("graphTooltip"), "graphTooltip"),
            "description": dashboard.get("description", ""),
            "editable": bool(dashboard.get("editable", False)),
            "elements": elements,
            "layout": convert_layout(panels),
            "links": [],
            "liveNow": False,
            "preload": False,
            "tags": dashboard.get("tags", []),
            "timeSettings": {
                "timezone": dashboard.get("timezone") or "browser",
                "from": time.get("from", "now-6h"),
                "to": time.get("to", "now"),
                "autoRefresh": dashboard.get("refresh", ""),
                "autoRefreshIntervals": timepicker.get(
                    "refresh_intervals", AUTO_REFRESH_INTERVALS
                ),
                "fiscalYearStartMonth": dashboard.get("fiscalYearStartMonth", 0),
            },
            "title": title,
            "variables": [
                convert_variable(variable)
                for variable in (dashboard.get("templating") or {}).get("list", [])
            ],
        },
    }


def summarize(spec):
    summary = {}
    for key, element in spec.get("elements", {}).items():
        panel = element.get("spec", {})
        queries = sorted(
            json.dumps(query["spec"]["query"]["spec"], sort_keys=True)
            for query in panel.get("data", {}).get("spec", {}).get("queries", [])
        )
        summary[key] = (panel.get("title", ""), queries)
    return summary


def diff(previous, current):
    lines = []
    for key in sorted(set(current) - set(previous)):
        lines.append(f"added: {key} {current[key][0]!r}")
    for key in sorted(set(previous) - set(current)):
        lines.append(f"removed: {key} {previous[key][0]!r}")
    for key in sorted(set(previous) & set(current)):
        old_title, old_queries = previous[key]
        new_title, new_queries = current[key]
        if old_title != new_title:
            lines.append(f"retitled: {key} {old_title!r} -> {new_title!r}")
        if old_queries != new_queries:
            lines.append(f"queries changed: {key} {new_title!r}")
    return lines


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("classic", help="classic dashboard JSON, or - for stdin")
    parser.add_argument("--output", help="write the v2 resource here instead of stdout")
    parser.add_argument("--uid", help="override the dashboard UID (metadata.name)")
    parser.add_argument(
        "--diff",
        metavar="V2_JSON",
        help="print how the conversion differs from an existing v2 dashboard",
    )
    args = parser.parse_args()

    try:
        if args.classic == "-":
            dashboard = json.load(sys.stdin)
        else:
            with open(args.classic, encoding="utf-8") as handle:
                dashboard = json.load(handle)
        converted = convert(dashboard, args.uid)
        if args.diff:
            with open(args.diff, encoding="utf-8") as handle:
                previous = summarize(json.load(handle).get("spec", {}))
            for line in diff(previous, summarize(converted["spec"])):
                print(line, file=sys.stderr)
    except ConversionError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1

    text = json.dumps(converted, indent=2, ensure_ascii=False) + "\n"
    if args.output:
        with open(args.output, "w", encoding="utf-8") as handle:
            handle.write(text)
    else:
        sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
