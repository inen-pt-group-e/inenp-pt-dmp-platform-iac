# Application & platform monitoring (Google Cloud Monitoring).
# GKE already exports pod/container/node metrics, so this only defines the monitoring "page"
# (per-tenant resource consumption + health, plus platform consumption) and an uptime check
# with alerting on the public endpoint. No in-cluster components -> no extra node cost.

variable "monitoring_uptime_host" {
  description = "Public host to run the uptime check against"
  type        = string
  default     = "acme.mcce-project.xyz"
}

variable "alert_notification_email" {
  description = "Email address that receives platform alerts"
  type        = string
  default     = "r.matthias3@gmail.com"
}

resource "google_monitoring_uptime_check_config" "tenant_app" {
  project      = var.project_id
  depends_on   = [google_project_iam_member.terraform_pipeline]
  display_name = "tenant-app-uptime"
  timeout      = "10s"
  period       = "60s"

  http_check {
    path           = "/"
    port           = 443
    use_ssl        = true
    validate_ssl   = true
    request_method = "GET"

    accepted_response_status_codes {
      status_class = "STATUS_CLASS_2XX"
    }
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = var.monitoring_uptime_host
    }
  }
}

resource "google_monitoring_notification_channel" "email" {
  project      = var.project_id
  depends_on   = [google_project_iam_member.terraform_pipeline]
  display_name = "Platform Alerts Email"
  type         = "email"

  labels = {
    email_address = var.alert_notification_email
  }
}

resource "google_monitoring_alert_policy" "tenant_app_down" {
  project      = var.project_id
  depends_on   = [google_project_iam_member.terraform_pipeline]
  display_name = "Tenant app endpoint down"
  combiner     = "OR"

  conditions {
    display_name = "Uptime check failing"

    condition_threshold {
      filter = join("", [
        "resource.type = \"uptime_url\" ",
        "AND metric.type = \"monitoring.googleapis.com/uptime_check/check_passed\" ",
        "AND metric.label.check_id = \"${google_monitoring_uptime_check_config.tenant_app.uptime_check_id}\"",
      ])
      comparison      = "COMPARISON_GT"
      threshold_value = 1
      duration        = "60s"

      trigger {
        count = 1
      }

      aggregations {
        alignment_period     = "1200s"
        per_series_aligner   = "ALIGN_NEXT_OLDER"
        cross_series_reducer = "REDUCE_COUNT_FALSE"
        group_by_fields      = ["resource.label.project_id", "resource.label.host"]
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]
}

resource "google_monitoring_dashboard" "platform" {
  project    = var.project_id
  depends_on = [google_project_iam_member.terraform_pipeline]

  dashboard_json = jsonencode({
    displayName = "Platform & Tenant Monitoring"
    gridLayout = {
      columns = 2
      widgets = [
        {
          title = "Tenant CPU (cores) by namespace"
          xyChart = {
            dataSets = [{
              plotType = "LINE"
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "metric.type=\"kubernetes.io/container/cpu/core_usage_time\" resource.type=\"k8s_container\" resource.label.namespace_name=monitoring.regex.full_match(\"tenant-.*\")"
                  aggregation = {
                    alignmentPeriod    = "60s"
                    perSeriesAligner   = "ALIGN_RATE"
                    crossSeriesReducer = "REDUCE_SUM"
                    groupByFields      = ["resource.label.namespace_name"]
                  }
                }
              }
            }]
          }
        },
        {
          title = "Tenant memory (bytes) by namespace"
          xyChart = {
            dataSets = [{
              plotType = "LINE"
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "metric.type=\"kubernetes.io/container/memory/used_bytes\" resource.type=\"k8s_container\" resource.label.namespace_name=monitoring.regex.full_match(\"tenant-.*\")"
                  aggregation = {
                    alignmentPeriod    = "60s"
                    perSeriesAligner   = "ALIGN_MEAN"
                    crossSeriesReducer = "REDUCE_SUM"
                    groupByFields      = ["resource.label.namespace_name"]
                  }
                }
              }
            }]
          }
        },
        {
          title = "Container restarts by namespace"
          xyChart = {
            dataSets = [{
              plotType = "LINE"
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "metric.type=\"kubernetes.io/container/restart_count\" resource.type=\"k8s_container\" resource.label.namespace_name=monitoring.regex.full_match(\"tenant-.*\")"
                  aggregation = {
                    alignmentPeriod    = "60s"
                    perSeriesAligner   = "ALIGN_DELTA"
                    crossSeriesReducer = "REDUCE_SUM"
                    groupByFields      = ["resource.label.namespace_name"]
                  }
                }
              }
            }]
          }
        },
        {
          title = "Endpoint availability (uptime check)"
          xyChart = {
            dataSets = [{
              plotType = "LINE"
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "metric.type=\"monitoring.googleapis.com/uptime_check/check_passed\" resource.type=\"uptime_url\""
                  aggregation = {
                    alignmentPeriod    = "300s"
                    perSeriesAligner   = "ALIGN_FRACTION_TRUE"
                    crossSeriesReducer = "REDUCE_MEAN"
                    groupByFields      = ["resource.label.host"]
                  }
                }
              }
            }]
          }
        },
        {
          title = "Cluster CPU utilization (nodes)"
          xyChart = {
            dataSets = [{
              plotType = "LINE"
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "metric.type=\"kubernetes.io/node/cpu/allocatable_utilization\" resource.type=\"k8s_node\""
                  aggregation = {
                    alignmentPeriod    = "60s"
                    perSeriesAligner   = "ALIGN_MEAN"
                    crossSeriesReducer = "REDUCE_MEAN"
                  }
                }
              }
            }]
          }
        },
        {
          title = "Cluster memory utilization (nodes)"
          xyChart = {
            dataSets = [{
              plotType = "LINE"
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "metric.type=\"kubernetes.io/node/memory/allocatable_utilization\" resource.type=\"k8s_node\""
                  aggregation = {
                    alignmentPeriod    = "60s"
                    perSeriesAligner   = "ALIGN_MEAN"
                    crossSeriesReducer = "REDUCE_MEAN"
                  }
                }
              }
            }]
          }
        }
      ]
    }
  })
}
