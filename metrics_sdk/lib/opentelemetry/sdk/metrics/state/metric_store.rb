# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

module OpenTelemetry
  module SDK
    module Metrics
      module State
        # @api private
        #
        # The MetricStore module provides SDK internal functionality that is not a part of the
        # public API.
        class MetricStore
          def initialize
            @mutex = Mutex.new
            @epoch_start_time = now_in_nano
            @epoch_end_time = nil
            @metric_streams = []
            OpenTelemetry.logger.info("ZZZ MetricStore initialized")
          end

          def collect
            @mutex.synchronize do
              OpenTelemetry.logger.info("ZZZ MetricStore.collect starting collection from #{@metric_streams.length} metric streams")
              @epoch_end_time = now_in_nano
              # snapshot = @metric_streams.map { |ms| ms.collect(@epoch_start_time, @epoch_end_time) }
              snapshot = @metric_streams.flat_map { |ms| ms.collect(@epoch_start_time, @epoch_end_time) }
              @epoch_start_time = @epoch_end_time
              OpenTelemetry.logger.info("ZZZ MetricStore.collect collected #{snapshot.length} metrics")
              snapshot
            end
          end

          def add_metric_stream(metric_stream)
            @mutex.synchronize do
              OpenTelemetry.logger.info("ZZZ MetricStore.add_metric_stream adding metric stream: #{metric_stream.name} (#{metric_stream.instrument_kind})")
              @metric_streams = @metric_streams.dup.push(metric_stream)
              OpenTelemetry.logger.info("ZZZ MetricStore.add_metric_stream now has #{@metric_streams.length} metric streams")
              nil
            end
          end

          private

          def now_in_nano
            (Time.now.to_r * 1_000_000_000).to_i
          end
        end
      end
    end
  end
end
