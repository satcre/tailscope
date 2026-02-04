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

  describe ".analyze_file" do
    let(:bad_model_path) { File.join(fixtures_root, "app", "models", "bad_model.rb") }
    let(:good_model_path) { File.join(fixtures_root, "app", "models", "good_model.rb") }

    it "returns an array of issues for a single file" do
      issues = described_class.analyze_file(bad_model_path)
      expect(issues).to be_an(Array)
      issues.each do |issue|
        expect(issue).to respond_to(:title)
        expect(issue).to respond_to(:description)
        expect(issue).to respond_to(:severity)
        expect(issue).to respond_to(:source_file)
        expect(issue).to respond_to(:source_line)
      end
    end

    it "returns empty array for non-existent file" do
      expect(described_class.analyze_file("/nonexistent.rb")).to eq([])
    end

    it "returns empty array for non-Ruby file" do
      non_ruby = File.join(fixtures_root, "test.txt")
      File.write(non_ruby, "not ruby")
      expect(described_class.analyze_file(non_ruby)).to eq([])
      File.delete(non_ruby) if File.exist?(non_ruby)
    end

    it "applies model-specific detectors to model files" do
      issues = described_class.analyze_file(bad_model_path)
      titles = issues.map(&:title)
      expect(titles).to include("Missing Validations — BadModel")
    end

    it "applies general detectors to all Ruby files" do
      issues = described_class.analyze_file(bad_model_path)
      titles = issues.map(&:title)
      expect(titles).to include("TODO Comment")
    end

    it "does not flag issues in clean files" do
      issues = described_class.analyze_file(good_model_path)
      expect(issues).to be_empty
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

  describe "SOLID principle detectors" do
    let(:solid_violations_path) { File.join(fixtures_root, "app", "models", "solid_violations.rb") }

    context "with complex conditionals" do
      it "flags multiple AND/OR operators" do
        issues = described_class.analyze_file(solid_violations_path)
        issue = issues.find { |i| i.title =~ /Complex Conditional/ }
        expect(issue).not_to be_nil
        expect(issue.severity).to eq(:warning)
        expect(issue.description).to match(/AND\/OR/)
      end
    end

    context "with deep nesting" do
      it "flags 4+ indentation levels" do
        issues = described_class.analyze_file(solid_violations_path)
        issue = issues.find { |i| i.title =~ /Deep Nesting/ }
        expect(issue).not_to be_nil
        expect(issue.severity).to eq(:warning)
        expect(issue.description).to match(/nested/)
      end
    end

    context "with god object" do
      it "flags classes with 7+ dependencies" do
        issues = described_class.analyze_file(solid_violations_path)
        issue = issues.find { |i| i.title =~ /God Object/ }
        expect(issue).not_to be_nil
        expect(issue.severity).to eq(:warning)
        expect(issue.description).to match(/dependencies/)
      end
    end

    context "with feature envy" do
      it "flags methods using mostly external data" do
        issues = described_class.analyze_file(solid_violations_path)
        issue = issues.find { |i| i.title =~ /Feature Envy/ }
        expect(issue).not_to be_nil
        expect(issue.severity).to eq(:info)
        expect(issue.description).to match(/other objects|another class/)
      end
    end

    context "with boolean parameters" do
      it "flags flag arguments" do
        issues = described_class.analyze_file(solid_violations_path)
        issue = issues.find { |i| i.title =~ /Boolean Parameter/ }
        expect(issue).not_to be_nil
        expect(issue.severity).to eq(:info)
        expect(issue.description).to match(/boolean.*parameter/i)
      end
    end

    context "with large parameter lists" do
      it "flags methods with 4+ parameters" do
        issues = described_class.analyze_file(solid_violations_path)
        issue = issues.find { |i| i.title =~ /Long Parameter List/ }
        expect(issue).not_to be_nil
        expect(issue.severity).to eq(:warning)
        expect(issue.description).to match(/parameters/)
      end
    end

    context "with primitive obsession" do
      it "flags large hash literals" do
        issues = described_class.analyze_file(solid_violations_path)
        issue = issues.find { |i| i.title =~ /Primitive Obsession/ && i.description =~ /hash/ }
        expect(issue).not_to be_nil
        expect(issue.severity).to eq(:info)
      end

      it "flags string validation patterns" do
        issues = described_class.analyze_file(solid_violations_path)
        issue = issues.find { |i| i.title =~ /Primitive Obsession/ && i.description =~ /email|phone/ }
        expect(issue).not_to be_nil
        expect(issue.severity).to eq(:info)
      end
    end

    context "with explanatory comments" do
      it "flags comments explaining what instead of why" do
        issues = described_class.analyze_file(solid_violations_path)
        issue = issues.find { |i| i.title =~ /Explanatory Comment/ }
        expect(issue).not_to be_nil
        expect(issue.severity).to eq(:info)
        expect(issue.description).to match(/self-documenting/)
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

    it "generates a fingerprint for each issue" do
      issues = described_class.analyze_all(source_root: fixtures_root)
      issues.each do |issue|
        expect(issue.fingerprint).to be_a(String)
        expect(issue.fingerprint.length).to eq(16)
      end
    end

    it "generates deterministic fingerprints" do
      issues1 = described_class.analyze_all(source_root: fixtures_root)
      issues2 = described_class.analyze_all(source_root: fixtures_root)
      fps1 = issues1.map(&:fingerprint).sort
      fps2 = issues2.map(&:fingerprint).sort
      expect(fps1).to eq(fps2)
    end
  end
end
