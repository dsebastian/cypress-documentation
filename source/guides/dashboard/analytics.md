---
title: Analytics
---

The Cypress Dashboard provides Analytics to offer insight into metrics like runs over time, run duration and visibility into tests suite size over time.

{% note info %}
{% badge info Beta %} Dashboard Analytics is currently in beta.
{% endnote %}

{% imgTag /img/dashboard/analytics/dashboard-analytics-overview.png "Dashboard Analytics Screenshot" %}

# Usage

## Runs over time

This report allows you to see the number of runs your organization has recorded to the Cypress Dashboard, broken down by the final status of the run. Each run represents a {% url "`cypress run`" command-line#cypress-run %} using the {% url "`--record`" command-line#cypress-run-record-key-lt-record-key-gt %} flag for the project being tested.

{% imgTag /img/dashboard/analytics/dashboard-analytics-runs-over-time.png "Dashboard Analytics Runs Over Time Screenshot" %}

### Filters

**Results may be filtered by:**

- Branch
- Time Range
- Time Interval *(Hourly, Daily, Weekly, Monthly, Quarterly)*

{% imgTag /img/dashboard/analytics/dashboard-analytics-runs-over-time-filters.png "Dashboard Analytics Runs Over Time Filters Screenshot" %}


### Results

The total runs over time are displayed for passed, failed, running, timed out and errored tests, respective of the filters selected.

The results may be downloaded as a comma-separated values (CSV) file for further analysis.
This can be done via the download icon to the right of the filters.

{% imgTag /img/dashboard/analytics/dashboard-analytics-runs-over-time-graph.png "Dashboard Analytics Runs Over Time Graph Screenshot" %}

### Key Performance Indicators

Total runs, average per day, passed runs and failed runs are computed respective of the filters selected.

{% imgTag /img/dashboard/analytics/dashboard-analytics-runs-over-time-kpi.png "Dashboard Analytics Runs Over Time KPI Screenshot" %}

A table of results grouped by date for the time range filter is displayed with passed, failed, running, timed out and errored columns.

{% imgTag /img/dashboard/analytics/dashboard-analytics-runs-over-time-table.png "Dashboard Analytics Runs Over Time Table Screenshot" %}

# Performance

## Run duration

You can use the 'run duration' analytics to see the average duration of a Cypress run for your project, including how test parallelization is impacting your total run time.

{% note info %}
Only passing runs are included in this analytic. Failing or errored runs can sway the average away from its typical duration, so they are not included.
{% endnote %}

{% imgTag /img/dashboard/analytics/dashboard-analytics-run-duration.png "Dashboard Analytics Run Duration Screenshot" %}

### Filters

**Results may be filtered by:**

- Branch
- Run Group
- Time Range
- Time Interval *(Hourly, Daily, Weekly, Monthly, Quarterly)*

{% imgTag /img/dashboard/analytics/dashboard-analytics-run-duration-filters.png "Dashboard Analytics Run Duration Filters Screenshot" %}

### Results

The average run duration over time is displayed respective of the filters selected.

The results may be downloaded as a comma-separated values (CSV) file for further analysis.
This can be done via the download icon to the right of the filters.

{% imgTag /img/dashboard/analytics/dashboard-analytics-run-duration-graph.png "Dashboard Analytics Run Duration Graph Screenshot" %}

### Key Performance Indicators

Average parallelization, average run duration and time saved from parallelization are computed respective of the filters selected.

{% imgTag /img/dashboard/analytics/dashboard-analytics-run-duration-kpi.png "Dashboard Analytics Run Duration KPI Screenshot" %}

A table of results grouped by date for the time range filter is displayed with average runtime, concurrency and time saved from parallelization columns.

{% imgTag /img/dashboard/analytics/dashboard-analytics-run-duration-table.png "Dashboard Analytics Run Duration Table Screenshot" %}

# Process

## Test suite size

You can get an overview of how you test suite is growing over time with this report. It calculates the average number of test cases executed per run for each day in the given time period.

{% note info %}
This analytic excludes runs that errored or timed out since they don't accurately represent the size of your test suite.
{% endnote %}

{% imgTag /img/dashboard/analytics/dashboard-analytics-test-suite-size.png "Dashboard Analytics Test Suite Size Screenshot" %}

### Filters

**Results may be filtered by:**

- Branch
- Run Group
- Time Range

{% imgTag /img/dashboard/analytics/dashboard-analytics-test-suite-size-filters.png "Dashboard Analytics Test Suite Size Filters Screenshot" %}

### Results

The average test suite size over time is displayed respective of the filters selected.

The results may be downloaded as a comma-separated values (CSV) file for further analysis.
This can be done via the download icon to the right of the filters.

{% imgTag /img/dashboard/analytics/dashboard-analytics-test-suite-size-graph.png "Dashboard Analytics Test Suite Size Graph Screenshot" %}

### Key Performance Indicators

Unique tests and number of spec files are computed respective of the filters selected.

{% imgTag /img/dashboard/analytics/dashboard-analytics-test-suite-size-kpi.png "Dashboard Analytics Test Suite Size KPI Screenshot" %}

A table of results grouped by date for the time range filter is displayed with unique tests and spec files.

{% imgTag /img/dashboard/analytics/dashboard-analytics-test-suite-size-table.png "Dashboard Analytics Test Suite Size Table Screenshot" %}