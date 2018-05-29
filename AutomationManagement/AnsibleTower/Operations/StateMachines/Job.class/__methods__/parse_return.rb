#
# Description: Given a Ansible Job Id, get the magic return result and put into $evm.root['from_ansible']
#

require 'rest-client'

module AnsibleTowerVariablePassing
  module Automate
    module AutomationManagement
      module AnsibleTower
        module Operations
          module StateMachines
            module Job
              class ParseReturn
                include RedHatConsulting_Utilities::StdLib::Core
                JOB_CLASS = 'ManageIQ_Providers_AnsibleTower_AutomationManager_Job'.freeze
                WORKING = 'WORKING'.freeze
                REST_TRIGGER = 'Standard Output too large to display'.freeze
                RS = '¾'.freeze # '\u001E'
                GET_DATA_RE = /#{RS}(.+?)#{RS}/

                def initialize(handle = $evm)
                  @handle = handle
                  @debug = true
                end

                def main
                  job = ansible_job
                  if @debug
                    log(:info, "start of job dump")
                    dump_thing(job)
                    log(:info, "End of job dump")
                  end

                  job_results = get_tower_job_results(job.ems_ref)
                  if @debug
                    log(:info, "start of job results dump")
                    log(:info, job_results['artifacts'])
                    log(:info, "End of job results dump")
                  end


                  @handle.root['from_ansible'] = job_results['artifacts']['for_cf']
                  @handle.set_state_var(:from_ansible, job_results['artifacts']['for_cf'].to_json)

                end

                private

                def ansible_job
                  job_id = @handle.get_state_var(:ansible_job_id)
                  if job_id.nil?
                    @handle.log(:error, 'Ansible job id not found')
                    exit(MIQ_ERROR)
                  end
                  fetch_job(job_id)
                end

                def fetch_job(job_id)
                  job = @handle.vmdb(JOB_CLASS).find(job_id)
                  if job.nil?
                    @handle.log(:error, "Ansible job with id : #{job_id} not found")
                    exit(MIQ_ERROR)
                  end
                  @job = job
                  job
                end

                # Get Job attributes from Ansible Tower
                # Function:
                #      Performs a direct REST call against Ansible Tower to get job results
                # Returns:
                #      A the json parsed job result
                # Requires:
                #      tower_job_id - this is the id of the job in ansible tower - NOT the internal MIQ job ID
                #           hint: job.ems_ref
                #
                def get_tower_job_results(tower_job_id)
                  begin
                    function_name = 'get_tower_job_results'.freeze

                    # Pull tower details from the tower object
                    tower = @job.ext_management_system
                    tower_user = tower.authentication_userid
                    tower_pass = tower.authentication_password
                    tower_url  = tower.url
                    tower_name = tower.name

                    # Verify username and password are set
                    unless tower_pass && tower_pass
                      raise "Function: #{function_name} unable to get credentials from tower object."
                    end

                    log(:info, "Got a tower: [#{tower_name}] with username: [#{tower_user}]") if @debug
                    log(:info, "\tand pass of size: [#{tower_pass.length}] at [#{tower_url}]") if @debug


                    # set the parameters for the API call
                    params = {
                      method: :get,
                      url: "#{tower_url}/jobs/#{tower_job_id}",
                      verify_ssl: false,
                      headers: { authorization: "Basic #{Base64.strict_encode64("#{tower_user}:#{tower_pass}")}" }
                    }

                    # Query Tower via REST
                    response = RestClient::Request.new(params).execute
                  rescue => err
                    log(:error, "Function: #{function_name}, Error: #{err}. Returning nil value")
                    return nil
                  end
                  JSON.parse(response.body)
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
  AnsibleTowerVariablePassing::Automate::AutomationManagement::AnsibleTower::Operations::StateMachines::Job::ParseReturn.new.main
end
