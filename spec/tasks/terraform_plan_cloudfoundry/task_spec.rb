# encoding: utf-8
require 'yaml'
require 'tmpdir'

describe 'terraform_plan_cloudfoundry task' do
  EXPECTED_TERRAFORM_VERSION='0.9.8'
  EXPECTED_PROVIDER_CLOUDFOUNDRY_VERSION='v0.7.3'

  context 'when pre-requisite are valid' do
    before(:context) do
      @generated_files = Dir.mktmpdir
      @spec_applied = Dir.mktmpdir
      @terraform_tfvars = File.join(File.dirname(__FILE__), 'terraform-tfvars')

      @output = execute('-c concourse/tasks/terraform_plan_cloudfoundry.yml ' \
        '-i secret-state-resource=spec/tasks/terraform_plan_cloudfoundry/secret-state-resource ' \
        '-i spec-resource=spec/tasks/terraform_plan_cloudfoundry/spec-resource ' \
        "-i terraform-tfvars=#{@terraform_tfvars} " \
        "-o generated-files=#{@generated_files} " \
        "-o spec-applied=#{@spec_applied} ",
                        'SPEC_PATH' => '',
                        'SECRET_STATE_FILE_PATH' => 'no-tfstate-dir')
    end

    after(:context) do
      FileUtils.rm_rf @generated_files
      FileUtils.rm_rf @spec_applied
    end

    it 'ensures terraform version is correct' do
      expect(@output).to include("Terraform v#{EXPECTED_TERRAFORM_VERSION}")
    end

    it 'ensures terraform cloudfoundry provider version is correct' do
      expect(@output).to include("terraform-provider-cloudfoundry-#{EXPECTED_PROVIDER_CLOUDFOUNDRY_VERSION} has been installed")
    end

    it 'ensures tfvars files are also in generated-files' do
      expect(Dir.entries(@generated_files)).to eq(Dir.entries(@terraform_tfvars))
    end

  end

  context 'when specs are only in spec-resource' do

    before(:context) do
      @generated_files = Dir.mktmpdir
      @spec_applied = Dir.mktmpdir
      @terraform_tfvars = File.join(File.dirname(__FILE__), 'terraform-tfvars')

      @output = execute('-c concourse/tasks/terraform_plan_cloudfoundry.yml ' \
        '-i secret-state-resource=spec/tasks/terraform_plan_cloudfoundry/secret-state-resource ' \
        '-i spec-resource=spec/tasks/terraform_plan_cloudfoundry/spec-resource ' \
        "-i terraform-tfvars=#{@terraform_tfvars} " \
        "-o generated-files=#{@generated_files} " \
        "-o spec-applied=#{@spec_applied} ",
        'SPEC_PATH' =>'spec-only',
        'SECRET_STATE_FILE_PATH' => 'no-tfstate-dir' )
    end

    after(:context) do
      FileUtils.rm_rf @generated_files
      FileUtils.rm_rf @spec_applied
    end

    it 'plans to add only one change' do
      expect(@output).to include('Plan:')
        include('1 to add, 0 to change, 0 to destroy.')
    end

    it 'emulates spec file processing' do
      expect(@output).to include('content:').and \
        include('"this file is generated by terraform spec_only resource !"')
    end

    it 'contains only spec files in spec-applied' do
      expect(Dir.entries(@spec_applied)).to eq(['.', '..', 'create-file.tf'])
    end

    it 'copies terraform-tfvars files in generated-files output' do
      expect(Dir.entries(@generated_files)).to eq(Dir.entries(@terraform_tfvars))
    end

  end

  context 'when specs are in resource dirs' do

    before(:context) do
      @generated_files = Dir.mktmpdir
      @spec_applied = Dir.mktmpdir
      @spec_resource = File.join(File.dirname(__FILE__), 'spec-resource')
      @secret_resource = File.join(File.dirname(__FILE__), 'secret-state-resource')
      @terraform_tfvars = File.join(File.dirname(__FILE__), 'terraform-tfvars')

      @output = execute('-c concourse/tasks/terraform_plan_cloudfoundry.yml ' \
        "-i secret-state-resource=#{@secret_resource} " \
        "-i spec-resource=#{@spec_resource} " \
        "-i terraform-tfvars=#{@terraform_tfvars} " \
        "-o generated-files=#{@generated_files} " \
        "-o spec-applied=#{@spec_applied} ",
                        'SPEC_PATH' =>'spec',
                        'SECRET_STATE_FILE_PATH' => 'no-tfstate-dir')
    end

    after(:context) do
      FileUtils.rm_rf @generated_files
      FileUtils.rm_rf @spec_applied
    end

    it 'plans to add resources' do
      expect(@output).to include('Plan:')
      include('2 to add, 0 to change, 0 to destroy.')
    end

    it 'emulates all spec files processing' do
      expect(@output).to include('content:').and \
        include('"this file is generated by terraform spec resource !"').and \
        include('"this file is generated by terraform secret resource !"')
    end

    it 'copies all found spec files into spec-applied output' do
      spec_files_in_spec_resource = Dir.entries(File.join(@spec_resource, 'spec'))
      spec_files_in_secret_resource = Dir.entries(File.join(@secret_resource, 'spec'))
      all_spec_files = (spec_files_in_spec_resource + spec_files_in_secret_resource).uniq.sort
      expect(Dir.entries(@spec_applied).sort).to eq(all_spec_files.sort)
    end

    it 'copies terraform-tfvars files in generated-files output' do
      expect(Dir.entries(@generated_files)).to eq(Dir.entries(@terraform_tfvars))
    end

  end

  context 'when secrets specs overrides others' do

    before(:context) do
      @generated_files = Dir.mktmpdir
      @spec_applied = Dir.mktmpdir
      @terraform_tfvars = Dir.mktmpdir
      @spec_resource = File.join(File.dirname(__FILE__), 'spec-resource')
      @secret_resource = File.join(File.dirname(__FILE__), 'secret-state-resource')
      @spec_path = 'override'

      @output = execute('-c concourse/tasks/terraform_plan_cloudfoundry.yml ' \
        "-i secret-state-resource=#{@secret_resource} " \
        "-i spec-resource=#{@spec_resource} " \
        "-i terraform-tfvars=#{@terraform_tfvars} " \
        "-o generated-files=#{@generated_files} " \
        "-o spec-applied=#{@spec_applied} ",
                        'SPEC_PATH' => @spec_path,
                        'SECRET_STATE_FILE_PATH' => 'no-tfstate-dir')
    end

    after(:context) do
      FileUtils.rm_rf @generated_files
      FileUtils.rm_rf @spec_applied
      FileUtils.rm_rf @terraform_tfvars
    end

    it 'plans to add only one resource' do
      expect(@output).to include('Plan:')
      include('1 to add, 0 to change, 0 to destroy.')
    end

    it 'emulates secrets spec files processing' do
      expect(@output).to include('content:').and \
        include('"this file is generated by terraform secret resource !"')
    end

    it 'ignores specs from spec-resource' do
      expect(@output).not_to include('"this file is generated by terraform spec resource !"')
    end

    it 'copies secret spec files into spec-applied output' do
      spec_files_in_secret_resource = Dir.entries(File.join(@secret_resource, @spec_path)).sort
      expect(Dir.entries(@spec_applied).sort).to eq(spec_files_in_secret_resource)
    end

    it 'does not contain any files in generated-files output' do
      expect(Dir.entries(@generated_files)).to eq(['.','..'])
    end

  end

end
