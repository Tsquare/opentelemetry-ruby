# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

module OpenTelemetry
  module SDK
    module Metrics
      # The ConfiguratorPatch implements a hook to configure the metrics
      # portion of the SDK.
      module ConfiguratorPatch
        def add_metric_reader(metric_reader)
          OpenTelemetry.logger.info("ZZZ ConfiguratorPatch.add_metric_reader adding #{metric_reader.class.name}")
          @metric_readers << metric_reader
        end

        private

        def initialize
          super
          @metric_readers = []
        end

        # The metrics_configuration_hook method is where we define the setup process for the metrics SDK.
        def metrics_configuration_hook
          OpenTelemetry.logger.info("ZZZ ConfiguratorPatch.metrics_configuration_hook starting metrics setup")
          OpenTelemetry.meter_provider = Metrics::MeterProvider.new(resource: @resource)
          OpenTelemetry.logger.info("ZZZ ConfiguratorPatch.metrics_configuration_hook MeterProvider created")
          configure_metric_readers
          attach_fork_hooks!
          OpenTelemetry.logger.info("ZZZ ConfiguratorPatch.metrics_configuration_hook metrics setup completed")
        end

        def configure_metric_readers
          OpenTelemetry.logger.info("ZZZ ConfiguratorPatch.configure_metric_readers configuring metric readers")
          readers = @metric_readers.empty? ? wrapped_metric_exporters_from_env.compact : @metric_readers
          OpenTelemetry.logger.info("ZZZ ConfiguratorPatch.configure_metric_readers found #{readers.length} metric readers")
          readers.each do |r|
            OpenTelemetry.logger.info("ZZZ ConfiguratorPatch.configure_metric_readers adding #{r.class.name} to MeterProvider")
            OpenTelemetry.meter_provider.add_metric_reader(r)
          end
        end

        def wrapped_metric_exporters_from_env
          exporters = ENV.fetch('OTEL_METRICS_EXPORTER', 'otlp')
          OpenTelemetry.logger.info("ZZZ ConfiguratorPatch.wrapped_metric_exporters_from_env OTEL_METRICS_EXPORTER=#{exporters}")
          exporters.split(',').map do |exporter|
            case exporter.strip
            when 'none'
              OpenTelemetry.logger.info("ZZZ ConfiguratorPatch.wrapped_metric_exporters_from_env skipping 'none' exporter")
              nil
            when 'console'
              OpenTelemetry.logger.info("ZZZ ConfiguratorPatch.wrapped_metric_exporters_from_env creating console exporter")
              OpenTelemetry.meter_provider.add_metric_reader(Metrics::Export::PeriodicMetricReader.new(exporter: Metrics::Export::ConsoleMetricPullExporter.new))
            when 'in-memory'
              OpenTelemetry.logger.info("ZZZ ConfiguratorPatch.wrapped_metric_exporters_from_env creating in-memory exporter")
              OpenTelemetry.meter_provider.add_metric_reader(Metrics::Export::InMemoryMetricPullExporter.new)
            when 'otlp'
              OpenTelemetry.logger.info("ZZZ ConfiguratorPatch.wrapped_metric_exporters_from_env creating OTLP exporter")
              begin
                reader = Metrics::Export::PeriodicMetricReader.new(exporter: OpenTelemetry::Exporter::OTLP::Metrics::MetricsExporter.new)
                OpenTelemetry.logger.info("ZZZ ConfiguratorPatch.wrapped_metric_exporters_from_env OTLP exporter created successfully")
                OpenTelemetry.meter_provider.add_metric_reader(reader)
              rescue NameError
                OpenTelemetry.logger.warn 'The otlp metrics exporter cannot be configured - please add opentelemetry-exporter-otlp-metrics to your Gemfile, metrics will not be exported'
                nil
              end
            else
              OpenTelemetry.logger.warn "The #{exporter} exporter is unknown and cannot be configured, metrics will not be exported"
              nil
            end
          end
        end

        def attach_fork_hooks!
          OpenTelemetry.logger.info("ZZZ ConfiguratorPatch.attach_fork_hooks! attaching fork hooks")
          ForkHooks.attach!
        end
      end
    end
  end
end

OpenTelemetry::SDK::Configurator.prepend(OpenTelemetry::SDK::Metrics::ConfiguratorPatch)
