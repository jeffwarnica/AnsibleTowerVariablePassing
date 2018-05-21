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
                include RHC_StdLib::StdLib::Core
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
                    dump_thing(job_results['artifacts'])
                    log(:info, "End of job results dump")
                  end
                  #
                  # cfme_stdout = job.raw_stdout
                  #
                  # if cfme_stdout[0, REST_TRIGGER.length] == REST_TRIGGER
                  #   log(:info, 'Tower hates us, we need to REST the stdout')
                  #   dump_thing(job)
                  #   cfme_stdout = get_stdout_from_tower_via_rest(job.ems_ref)
                  # end
                  #
                  # log(:info, "STD OUT >>>>>>>>>>>>>>>>>>>>>>>#{cfme_stdout}<<<<<<<<<<<<<<<<<<<<<<") if @debug
                  #
                  # # if match = cfme_stdout.match(/☒(.+?)☒/)
                  #
                  # log(:info, "cfme_stdout.encoding = [#{cfme_stdout.encoding}]") if @debug
                  # log(:info, "GET_DATA_RE.encoding = [#{GET_DATA_RE.encoding}]") if @debug
                  # log(:info, "Script encoding is   = [#{__ENCODING__}]") if @debug
                  #
                  # if match = cfme_stdout.force_encoding("UTF-8").match(GET_DATA_RE)
                  #   goodstuff = match.captures[0]
                  #
                  #   # # somewhere along the line ruby double escaped things. Undo that, \\ -> \
                  #   # goodstuff.sub!("\\\\", "\\")
                  #   log(:info, "goodstuff >>>>>>>>>>>>>>>>>>>>>>>#{goodstuff}<<<<<<<<<<<<<<<<<<<<<<") if @debug
                  # else
                  #   log(:info, "Magic regexp failed. You sure you did the right bookending in your playbook? hint: [#{RS}]" )
                  #   exit MIQ_ERROR
                  # end
                  # goodstuff = eval("\"#{goodstuff}\"")
                  #
                  # log(:info, "eval'd and {}'d goodstuff >>>>>>>>>>>>>>>>>>>>>>>#{goodstuff}<<<<<<<<<<<<<<<<<<<<<<") if @debug
                  # parsed = JSON.parse(goodstuff)
                  # @handle.root['from_ansible'] = parsed
                  # log(:info, "parsed:>>>>>>>>>>>>>>>>#{parsed}<<<<<<<<<<<<<<<<<<") if @debug

                  @handle.root['from_ansible'] = job_results['artifacts']['for_cf']

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
                    log(:info, "Got a tower: [#{tower_name}] with username: [#{tower_user}]") if @debug
                    log(:info, "\tand pass of size: [#{tower_pass.length}] at [#{tower_url}]") if @debug


                    # Verify username and password are set
                    unless tower_pass && tower_pass
                      raise "Function: #{function_name} unable to get credentials from tower object."
                    end

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

                # Get STDOUT from Job Directly from Ansible Tower
                # Function:
                #      Performs a direct REST call against Ansible Tower to get job results
                # Returns:
                #      A REST response object
                #           hint: response text available via response.body
                # Requires:
                #      tower_job_id - this is the id of the job in ansible tower - NOT the internal MIQ job ID
                #           hint: job.ems_ref
                #
                def get_stdout_from_tower_via_rest(tower_job_id)
                  begin
                    function_name = "get_stdout_from_tower_via_rest"

                    # Pull tower details from the tower object
                    tower = @job.ext_management_system
                    tower_user = tower.authentication_userid
                    tower_pass = tower.authentication_password
                    tower_url  = tower.url
                    tower_name = tower.name
                    log(:info, "Got a tower: [#{tower_name}] with username: [#{tower_user}]") if @debug
                    log(:info, "\tand pass of size: [#{tower_pass.length}] at [#{tower_url}]") if @debug


                    # Verify username and password are set
                    if tower_pass && tower_pass

                      # set the parameters for the API call
                      params = {
                          :method => :get,
                          :url => "#{tower_url}/jobs/#{tower_job_id}/stdout/?format=txt_download",
                          :verify_ssl => false,
                          :headers => { :authorization => "Basic #{Base64.strict_encode64("#{tower_user}:#{tower_pass}")}" }
                      }

                      # Query Tower via REST
                      response = RestClient::Request.new(params).execute
                    else
                      raise "Function: #{function_name} unable to get credentials from tower object."
                    end
                  rescue => err
                    log(:error, "Function: #{function_name}, Error: #{err}. Returning nil value")
                    return nil
                  end
                  response = response.force_encoding('iso-8859-1').encode('utf-8')
                  response
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
