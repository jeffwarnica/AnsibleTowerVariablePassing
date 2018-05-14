#
# Description: Wait for the IP address to be available on the VM
# For VMWare for this to work the VMWare tools should be installed
# on the newly provisioned vm's

module AnsibleTowerVariablePassing
  module Automate
    module AutomationManagement
      module AnsibleTower
        module Operations
          module StateMachines
            module Job
              class WaitForIP
                include RHC_StdLib::StdLib::Core
                def initialize(handle = $evm)
                  @handle = handle
                end

                def main
                  if $evm.state_var_exist?(:skip_ansible_wait_for_ip) && $evm.get_state_var(:skip_ansible_wait_for_ip)
                    log(:info, 'Skipping waiting for IP')
                    @handle.root['ae_result'] = 'ok'
                    return
                  end
                  vm = @handle.root["miq_provision"].try(:destination)
                  vm ||= @handle.root["vm"]
                  vm ? check_ip_addr_available(vm) : vm_not_found
                end

                def check_ip_addr_available(vm)
                  ip_list = vm.ipaddresses
                  @handle.log(:info, "Current Power State #{vm.power_state}")
                  @handle.log(:info, "IP addresses for VM #{ip_list}")

                  if ip_list.empty?
                    vm.refresh
                    @handle.root['ae_result'] = 'retry'
                    @handle.root['ae_retry_interval'] = 1.minute
                  else
                    @handle.root['ae_result'] = 'ok'
                  end
                end

                def vm_not_found
                  @handle.root['ae_result'] = 'error'
                  @handle.log(:error, "VM not found")
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
  AnsibleTowerVariablePassing::Automate::AutomationManagement::AnsibleTower::Operations::StateMachines::Job::WaitForIP.new.main
end
