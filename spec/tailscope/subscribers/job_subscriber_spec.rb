# frozen_string_literal: true

require "spec_helper"

RSpec.describe Tailscope::Subscribers::JobSubscriber do
  subject(:subscriber) { described_class.new }

  let(:job) do
    double("Job",
      class: double("Class", name: "SendEmailJob"),
      job_id: "job-abc-123",
      queue_name: "default"
    )
  end

  after do
    Thread.current[:tailscope_request_id] = nil
    Thread.current[:tailscope_request_start] = nil
    Tailscope.configuration.enabled = false
  end

  describe "#handle_enqueue" do
    let(:event) { double("Event", duration: 5.0, payload: { job: job }) }

    it "does nothing when disabled" do
      Tailscope.configuration.enabled = false
      expect(Tailscope::Storage).not_to receive(:record_job)
      subscriber.handle_enqueue(event)
    end

    context "when enabled" do
      before { Tailscope.configuration.enabled = true }

      it "records an enqueued job" do
        expect(Tailscope::Storage).to receive(:record_job).with(hash_including(
          job_class: "SendEmailJob",
          job_id: "job-abc-123",
          queue_name: "default",
          status: "enqueued",
          duration_ms: 5.0
        ))

        subscriber.handle_enqueue(event)
      end

      it "records a service when request_id is present" do
        Thread.current[:tailscope_request_id] = "req-123"

        expect(Tailscope::Storage).to receive(:record_job)
        expect(Tailscope::Storage).to receive(:record_service).with(hash_including(
          category: "job",
          name: "Enqueue SendEmailJob",
          request_id: "req-123"
        ))

        subscriber.handle_enqueue(event)
      end

      it "does not record a service when no request_id" do
        Thread.current[:tailscope_request_id] = nil

        expect(Tailscope::Storage).to receive(:record_job)
        expect(Tailscope::Storage).not_to receive(:record_service)

        subscriber.handle_enqueue(event)
      end
    end
  end

  describe "#handle_perform" do
    let(:event) { double("Event", duration: 250.0, payload: { job: job, exception_object: nil }) }

    it "does nothing when disabled" do
      Tailscope.configuration.enabled = false
      expect(Tailscope::Storage).not_to receive(:record_job)
      subscriber.handle_perform(event)
    end

    context "when enabled" do
      before { Tailscope.configuration.enabled = true }

      it "records a performed job" do
        expect(Tailscope::Storage).to receive(:record_job).with(hash_including(
          job_class: "SendEmailJob",
          job_id: "job-abc-123",
          queue_name: "default",
          status: "performed",
          duration_ms: 250.0
        ))

        subscriber.handle_perform(event)
      end

      it "records a failed job with error details" do
        error = RuntimeError.new("something broke")
        failed_event = double("Event", duration: 100.0, payload: { job: job, exception_object: error })

        expect(Tailscope::Storage).to receive(:record_job).with(hash_including(
          status: "failed",
          error_class: "RuntimeError",
          error_message: "something broke"
        ))

        subscriber.handle_perform(failed_event)
      end

      it "uses job tracking id as request_id" do
        expect(Tailscope::Storage).to receive(:record_job).with(hash_including(
          request_id: "job_job-abc-123"
        ))

        subscriber.handle_perform(event)
      end
    end
  end
end
