# codoo() {
#   systemctl is-active --quiet postgresql
#   [[ $? -ne 0 ]] && sudo systemctl start postgresql
#   ODOO_PATH=~/odoo-dev
#   local addons_path="--addons-path=$ODOO_PATH/addons,$ODOO_PATH/odoo/addons"
#   local cmd='odoo'
#   local args=''

#   add_path() {
#     local path=$(realpath $1)
#     if [[ -d $path ]]; then
#       for dir in $(exa -D $path); do
#         if [[ -f "$path/$dir/__init__.py" ]]; then
#           addons_path+=",$path"
#           return 0
#         fi
#       done
#     fi
#   }
#   add_path .

#   for i in $(seq 5); do
#     case $1 in
#       init)
#         args+=" -i all"
#         shift
#       ;;paths)
#         shift
#         for dir in ${1//,/ }; do
#           add_path $dir
#         done
#         shift
#       ;;db)
#         args="$args -d $(basename $(pwd))"
#         shift
#       ;;shell)
#         cmd+=" shell"
#         shift
#       ;;dev)
#         cmd+=" --dev=xml,reload,qweb,pdb,werkzeug"
#         shift
#     esac
#   done

#   unset add_path
#   $PREFIX $cmd -D $PWD/.cache/odoo $args $addons_path $@
# }
