

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_ansible() {
    if ! command -v ansible &> /dev/null; then
        print_error "Ansible is not installed. Please install Ansible first."
        print_status "You can install Ansible using: pip install ansible"
        exit 1
    fi
    print_status "Ansible is installed: $(ansible --version | head -n1)"
}

check_inventory() {
    if [ ! -f "inventory.ini" ]; then
        print_error "inventory.ini file not found!"
        print_status "Please create an inventory.ini file with your server details."
        exit 1
    fi
    print_status "Inventory file found."
}

create_structure() {
    print_status "Creating directory structure..."
    mkdir -p group_vars
    mkdir -p host_vars
    mkdir -p roles
    print_status "Directory structure created."
}

test_connectivity() {
    print_status "Testing connectivity to servers..."
    if ansible all -i inventory.ini -m ping; then
        print_status "All servers are reachable."
    else
        print_error "Some servers are not reachable. Please check your inventory and SSH keys."
        exit 1
    fi
}

deploy() {
    print_status "Starting deployment of Loki and Promtail..."
    
    # Run the playbook
    if ansible-playbook -i inventory.ini loki-promtail-playbook.yml --check; then
        print_status "Dry run completed successfully."
        read -p "Do you want to proceed with the actual deployment? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            ansible-playbook -i inventory.ini loki-promtail-playbook.yml
            print_status "Deployment completed!"
        else
            print_warning "Deployment cancelled by user."
        fi
    else
        print_error "Dry run failed. Please check the errors above."
        exit 1
    fi
}

verify_deployment() {
    print_status "Verifying deployment..."
    
    # Check if services are running
    ansible all -i inventory.ini -m shell -a "systemctl is-active loki"
    ansible all -i inventory.ini -m shell -a "systemctl is-active promtail"
    
    # Check if ports are listening
    ansible all -i inventory.ini -m shell -a "netstat -tlnp | grep -E ':(3100|9080)'"
    
    print_status "Verification completed."
}

show_menu() {
    echo
    echo "=== Loki and Promtail Deployment Script ==="
    echo "1. Check prerequisites"
    echo "2. Test connectivity"
    echo "3. Deploy Loki and Promtail"
    echo "4. Verify deployment"
    echo "5. Show service status"
    echo "6. Restart services"
    echo "7. Exit"
    echo
}

show_status() {
    print_status "Checking service status..."
    ansible all -i inventory.ini -m shell -a "systemctl status loki --no-pager -l"
    ansible all -i inventory.ini -m shell -a "systemctl status promtail --no-pager -l"
}

restart_services() {
    print_status "Restarting services..."
    ansible all -i inventory.ini -m shell -a "systemctl restart loki"
    ansible all -i inventory.ini -m shell -a "systemctl restart promtail"
    print_status "Services restarted."
}

main() {
    while true; do
        show_menu
        read -p "Please select an option (1-7): " choice
        
        case $choice in
            1)
                check_ansible
                check_inventory
                create_structure
                ;;
            2)
                test_connectivity
                ;;
            3)
                deploy
                ;;
            4)
                verify_deployment
                ;;
            5)
                show_status
                ;;
            6)
                restart_services
                ;;
            7)
                print_status "Goodbye!"
                exit 0
                ;;
            *)
                print_error "Invalid option. Please select 1-7."
                ;;
        esac
        
        echo
        read -p "Press Enter to continue..."
    done
}

main
