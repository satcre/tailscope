# frozen_string_literal: true

require "spec_helper"

RSpec.describe Tailscope::CodeAnalyzer do
  let(:fixtures_root) { File.expand_path("../../fixtures", __FILE__) }

  describe ".analyze_all" do
    it "returns an array of Issue structs" do
      issues = described_class.analyze_all(source_root: fixtures_root)
      expect(issues).to be_an(Array)
      issues.each do |issue|
        expect(issue).to be_a(Tailscope::Issue)
        expect(issue.type).to eq(:code_smell)
        expect(issue.raw_type).to eq("code_smell")
      end
    end

    it "returns empty array for non-existent directory" do
      expect(described_class.analyze_all(source_root: "/nonexistent")).to eq([])
    end
  end

  describe "model detectors" do
    context "with a model that has validations" do
      it "does not flag missing validations" do
        issues = described_class.analyze_all(source_root: fixtures_root)
        titles = issues.map(&:title)
        expect(titles).not_to include("Missing Validations — GoodModel")
      end
    end

    context "with a model that has no validations" do
      it "flags missing validations" do
        issues = described_class.analyze_all(source_root: fixtures_root)
        issue = issues.find { |i| i.title == "Missing Validations — BadModel" }
        expect(issue).not_to be_nil
        expect(issue.severity).to eq(:warning)
      end
    end

    context "with a model that has many callbacks" do
      it "flags callback abuse" do
        issues = described_class.analyze_all(source_root: fixtures_root)
        issue = issues.find { |i| i.title =~ /Callback Abuse/ }
        expect(issue).not_to be_nil
        expect(issue.severity).to eq(:warning)
        expect(issue.description).to match(/callbacks/)
      end
    end

    context "with a fat model" do
      it "flags mixed responsibilities" do
        issues = described_class.analyze_all(source_root: fixtures_root)
        issue = issues.find { |i| i.title =~ /Fat Model/ }
        expect(issue).not_to be_nil
        expect(issue.severity).to eq(:warning)
        expect(issue.description).to match(/SRP/)
      end
    end
  end

  describe "controller detectors" do
    context "with a controller that has authentication" do
      it "does not flag missing auth" do
        issues = described_class.analyze_all(source_root: fixtures_root)
        titles = issues.map(&:title)
        expect(titles).not_to include("Missing Authentication — GoodController")
      end
    end

    context "with a controller that lacks authentication" do
      it "flags missing authentication" do
        issues = described_class.analyze_all(source_root: fixtures_root)
        issue = issues.find { |i| i.title == "Missing Authentication — BadController" }
        expect(issue).not_to be_nil
        expect(issue.severity).to eq(:warning)
      end
    end

    context "with data exposure" do
      it "flags rendering full models as JSON" do
        issues = described_class.analyze_all(source_root: fixtures_root)
        issue = issues.find { |i| i.title =~ /Data Exposure/ }
        expect(issue).not_to be_nil
        expect(issue.severity).to eq(:critical)
      end
    end

    context "with direct SQL" do
      it "flags Arel.sql usage" do
        issues = described_class.analyze_all(source_root: fixtures_root)
        issue = issues.find { |i| i.title =~ /Arel\.sql/ }
        expect(issue).not_to be_nil
        expect(issue.severity).to eq(:warning)
      end
    end

    context "with fat controller action" do
      it "flags actions with too many lines" do
        issues = described_class.analyze_all(source_root: fixtures_root)
        issue = issues.find { |i| i.title =~ /Fat Controller Action/ }
        expect(issue).not_to be_nil
        expect(issue.description).to match(/lines/)
      end
    end

    context "with multiple model responsibilities" do
      it "flags controllers querying many models" do
        issues = described_class.analyze_all(source_root: fixtures_root)
        issue = issues.find { |i| i.title =~ /Multiple Responsibilities/ }
        expect(issue).not_to be_nil
        expect(issue.description).to match(/models/)
      end
    end
  end

  describe "general detectors" do
    context "with hardcoded secrets" do
      it "flags hardcoded secret constants" do
        issues = described_class.analyze_all(source_root: fixtures_root)
        issue = issues.find { |i| i.title == "Hardcoded Secret" }
        expect(issue).not_to be_nil
        expect(issue.severity).to eq(:critical)
      end
    end

    context "with TODO comments" do
      it "flags TODO/FIXME/HACK comments" do
        issues = described_class.analyze_all(source_root: fixtures_root)
        issue = issues.find { |i| i.title == "TODO Comment" }
        expect(issue).not_to be_nil
        expect(issue.severity).to eq(:info)
      end
    end

    context "with empty rescue blocks" do
      it "flags empty rescue blocks" do
        issues = described_class.analyze_all(source_root: fixtures_root)
        issue = issues.find { |i| i.title == "Empty Rescue Block" }
        expect(issue).not_to be_nil
        expect(issue.severity).to eq(:warning)
      end
    end

    context "with Law of Demeter violations" do
      it "flags long method chains" do
        issues = described_class.analyze_all(source_root: fixtures_root)
        issue = issues.find { |i| i.title =~ /Demeter/ }
        expect(issue).not_to be_nil
        expect(issue.severity).to eq(:info)
      end
    end
  end

  describe "issue structure" do
    it "returns issues with all required fields" do
      issues = described_class.analyze_all(source_root: fixtures_root)
      expect(issues).not_to be_empty

      issues.each do |issue|
        expect(issue.severity).to be_in([:critical, :warning, :info])
        expect(issue.title).to be_a(String)
        expect(issue.description).to be_a(String)
        expect(issue.source_file).to be_a(String)
        expect(issue.source_line).to be_a(Integer)
        expect(issue.suggested_fix).to be_a(String)
        expect(issue.occurrences).to eq(1)
        expect(issue.raw_ids).to eq([])
      end
    end
  end
end
