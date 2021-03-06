# frozen_string_literal: true

RSpec.describe SidekiqUniqueJobs::OnConflict::Replace do
  let(:strategy)    { described_class.new(item) }
  let(:lock_digest) { "uniquejobs:0781b1f587a9a8d08773f21ed752caed" }
  let(:block)       { -> { p "Hello" } }
  let(:digest)      { digests.entries.first }

  let(:item) do
    { "lock_digest" => lock_digest, "queue" => :customqueue }
  end

  describe "#call" do
    subject(:call) { strategy.call(&block) }

    before do
      jid
      digest
      allow(block).to receive(:call)
    end

    context "when job is retried" do
      let(:jid)  { "abcdefab" }
      let(:job)  { dump_json(item) }
      let(:item) do
        {
          "class" => "MyUniqueJob",
          "args" => [1, 2],
          "queue" => "customqueue",
          "jid" => jid,
          "retry_count" => 2,
          "failed_at" => Time.now.to_f,
          "lock_digest" => lock_digest,
        }
      end

      before { zadd("retry", Time.now.to_f.to_s, job) }

      it "removes the job from the retry set" do
        expect { call }.to change { retry_count }.from(1).to(0)
        expect(block).to have_received(:call)
      end
    end

    context "when job is scheduled" do
      let(:jid) { MyUniqueJob.perform_in(2000, 1, 1) }

      it "removes the job from the scheduled set" do
        expect { call }.to change { schedule_count }.from(1).to(0)
        expect(block).to have_received(:call)
      end
    end

    context "when job is enqueued" do
      let(:jid) { MyUniqueJob.perform_async(1, 1) }

      it "removes the job from the queue" do
        expect { call }.to change { queue_count(:customqueue) }.from(1).to(0)

        expect(block).to have_received(:call)
      end
    end
  end

  describe "#replace?" do
    subject { strategy.replace? }

    it { is_expected.to eq(true) }
  end
end
