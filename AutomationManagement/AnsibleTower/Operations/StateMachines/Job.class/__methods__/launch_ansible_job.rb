#
# Description: Launch a Ansible Job Template and save the job id
#              in the state variables so we can use it when we
#              wait for the job to finish.
#

module AnsibleTowerVariablePassing
  module Automate
    module AutomationManagement
      module AnsibleTower
        module Operations
          module StateMachines
            module Job
              class LaunchAnsibleJob
                include RHC_StdLib::StdLib::Core
                ANSIBLE_VAR_REGEX = Regexp.new(/(.*)=(.*$)/)
                ANSIBLE_DIALOG_VAR_REGEX = Regexp.new(/dialog_param_(.*)/)
                SCRIPT_CLASS = 'ManageIQ_Providers_AnsibleTower_AutomationManager_ConfigurationScript'.freeze
                JOB_CLASS = 'ManageIQ_Providers_AnsibleTower_AutomationManager_Job'.freeze
                MANAGER_CLASS = 'ManageIQ_Providers_AnsibleTower_AutomationManager'.freeze

                def initialize(handle = $evm)
                  @handle = handle
                end

                def main
                  dump_root()
                  run(job_template, target)
                end

                private

                def target
                  vm = @handle.root['vm'] || vm_from_request
                  vm.name if vm
                end

                def vm_from_request
                  @handle.root["miq_provision"].try(:destination)
                end

                def ansible_vars_from_objects(object, ext_vars)
                  return ext_vars unless object
                  ansible_vars_from_objects(object.parent, object_vars(object, ext_vars))
                end

                def object_vars(object, ext_vars)
                  # We are traversing the list twice because the object.attributes is a DrbObject
                  # and when we use each_with_object on a DrbObject, it doesn't seem to update the
                  # hash. We are investigating that
                  key_list = object.attributes.keys.select { |k| k.start_with?('param', 'dialog_param', 'for_ansible') }
                  key_list.each_with_object(ext_vars) do |key, hash|
                    if key.start_with?('param')
                      match_data = ANSIBLE_VAR_REGEX.match(object[key])
                      hash[match_data[1].strip] ||= match_data[2] if match_data
                    elsif key.starts_with?('dialog_param')
                      match_data = ANSIBLE_DIALOG_VAR_REGEX.match(key)
                      hash[match_data[1]] = object[key] if match_data
                    # elsif key == 'for_ansible'
                    #   hash['from_cf'] = object[key]
                    end
                  end
                end

                def ansible_vars_from_options(ext_vars)
                  options = @handle.root["miq_provision"].try(:options) || {}
                  options.each_with_object(ext_vars) do |(key, value), hash|
                    match_data = ANSIBLE_DIALOG_VAR_REGEX.match(key.to_s)
                    hash[match_data[1]] = value if match_data
                  end
                end

                def var_search(obj, name)
                  return nil unless obj
                  obj.attributes.key?(name) ? obj.attributes[name] : var_search(obj.parent, name)
                end

                def job_template
                  job_template = var_search(@handle.object, 'job_template') ||
                                 job_template_by_id ||
                                 job_template_by_provider ||
                                 job_template_by_name

                  if job_template.nil?
                    raise "Job Template not specified"
                  end
                  job_template
                end

                def job_template_name
                  @job_template_name ||= @handle.get_state_var(:job_template_name) ||
                                         var_search(@handle.object, 'job_template_name') ||
                                         var_search(@handle.object, 'dialog_job_template_name')
                  log(:info, "Found a job_template_name: [#{@job_template_name}]")
                  @job_template_name
                end

                def job_template_by_name
                  job_template_by_name= @handle.vmdb(SCRIPT_CLASS).where('lower(name) = ?', job_template_name.downcase).first if job_template_name
                  log(:info, "Unable to find job template in VMDB") if job_template_by_name.nil?
                  job_template_by_name
                end

                def job_template_by_id
                  job_template_id = var_search(@handle.object, 'job_template_id') ||
                                    var_search(@handle.object, 'dialog_job_template_id')
                  @handle.vmdb(SCRIPT_CLASS).where(:id => job_template_id).first if job_template_id
                end

                def job_template_by_provider
                  provider_name = var_search(@handle.object, 'ansible_tower_provider_name') ||
                                  var_search(@handle.object, 'dialog_ansible_tower_provider_name')
                  provider = @handle.vmdb(MANAGER_CLASS).where('lower(name) = ?', provider_name.downcase).first if provider_name
                  provider.configuration_scripts.detect { |s| s.name.casecmp(job_template_name).zero? } if provider && job_template_name
                end

                def extra_variables
                  result = ansible_vars_from_objects(@handle.object, {})
                  result = ansible_vars_from_options(result)

                  from_cf = JSON.parse(@handle.get_state_var(:for_ansible))
                  from_cf.each_with_index do |k, v|
                    result[k] = v
                  end
                  # result['from_cf'] = JSON.parse(@handle.get_state_var(:for_ansible))

                  # result['manageiq'] = manageiq_extra_vars()
                  # result['manageiq_connection'] = manageiq_connection_env
                  result
                end

                def run(job_template, target)
                  @handle.log(:info, "Processing Job Template #{job_template.name}")
                  args = {:extra_vars => extra_variables}
                  args[:limit] = target if target
                  @handle.log(:info, "Job Arguments #{args}")

                  job = @handle.vmdb(JOB_CLASS).create_job(job_template, args)

                  @handle.log(:info, "Scheduled Job ID: #{job.id} Ansible Job ID: #{job.ems_ref}")
                  @handle.set_state_var(:ansible_job_id, job.id)
                end
              end
            end
          end
        end
      end
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  AnsibleTowerVariablePassing::Automate::AutomationManagement::AnsibleTower::Operations::StateMachines::Job::LaunchAnsibleJob.new.main
end
