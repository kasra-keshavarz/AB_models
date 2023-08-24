def parse_args($array):
    array |
    to_entries | .[] |
    if (.key == "_triggers") then
        select ((.value | type == "array") and (.value | length != 0)) |
            .value | map("--" + . + " \\") | join(" \n")
    else 
        select (.value != "") |
            if (.value | type == "array") then
                "--" + .key + "=" + (.value | join(",")) + " \\"
            else
                "--" + .key + "=" + (.value) + " \\"
            end
    end
    ;

def count($array):
  array | length
  ;

def select_independants($array):
  array |
  to_entries | .[] | 
  select((.value == -1) or (.value == "-1")) |
  .key
  ;
