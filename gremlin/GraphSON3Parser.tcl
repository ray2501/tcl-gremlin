package require rl_json

package provide GraphSON3Parser 0.1

#
# GraphSON is a JSON-based format that is designed for human readable output 
# that is easily supported in any programming language through the wide-array 
# of JSON parsing libraries that exist on virtually all platforms.
#
# It is a GraphSON Version 3.0 parser to parse Gremlin Server output.
# 
namespace eval ::GraphSON3Parser {
    variable supportType [list \
        "g:Int32" \
        "g:Int64" \
        "g:Float" \
        "g:Double" \
        "g:Date" \
        "g:Timestamp" \
        "g:UUID" \
        "g:List" \
        "g:Set" \
        "g:Map" \
        "g:Class" \
        "g:Path" \
        "g:Vertex" \
        "g:VertexProperty" \
        "tinker:graph" \
        "g:Edge" \
        "g:Property" \
        "g:T"]

    proc parse {data} {
        if {[string compare [::rl_json::json type $data] "array"] != 0} {
            if {[::rl_json::json exists $data @type]} {
                set type [::rl_json::json get $data @type]

                if {[lsearch $::GraphSON3Parser::supportType $type] >= 0} {
                    switch $type {              
                    "g:Int32" -
                    "g:Int64" -
                    "g:Float" -
                    "g:Double" -
                    "g:Date" -
                    "g:Timestamp" {
                        set value [::rl_json::json extract $data @value]
                        return $value
                    }
                    "g:UUID" {
                        set value [::rl_json::json get $data @value]
                        return $value
                    }
                    "g:List" -
                    "g:Set" -
                    "g:Map" {
                        set listresult [list]
                        set value [::rl_json::json get $data @value]
                        set length [llength $value]
                        for {set i 0} {$i < $length} {incr i} {
                            set v [::rl_json::json extract $data @value $i]
                            set v2 [::GraphSON3Parser::parse $v]
                            lappend listresult $v2
                        }

                        return $listresult
                    }
                    "g:Class" {
                        set value [::rl_json::json get $data @value]
                        return $value
                    } 
                    "g:Path" {
                        set value [::rl_json::json extract $data @value "objects"]
                        set v [::GraphSON3Parser::parse $value]
                        return $v
                    }
                    "g:Vertex" {
                        set value [::rl_json::json extract $data @value id]
                        set v [::GraphSON3Parser::parse $value]
                        return [list vertex $v]
                    }
                    "g:VertexProperty" {
                        set value [::rl_json::json extract $data @value]
                        set v [::GraphSON3Parser::parse $value]
                        return $v
                    }
                    "tinker:graph" {
                        set value [::rl_json::json extract $data @value]
                        set v [::GraphSON3Parser::parse $value]
                        return $v
                    }
                    "g:Edge" {
                        set value [::rl_json::json extract $data @value id]
                        set e [::GraphSON3Parser::parse $value]
                        set tlabel [::rl_json::json extract $data @value "label"]
                        set vlabel [::GraphSON3Parser::parse $tlabel]
                        set inV [::rl_json::json extract $data @value "inV"]
                        set vinV [::GraphSON3Parser::parse $inV]
                        set outV [::rl_json::json extract $data @value "outV"]
                        set voutV [::GraphSON3Parser::parse $outV]
                        return [list edge $e [list $voutV $vlabel $vinV]]
                    }
                    "g:Property" {
                        set key [::rl_json::json get $data @value key]
                        set value [::rl_json::json extract $data @value value]
                        set v [::GraphSON3Parser::parse $value]
                        return [list $key $v]
                    }
                    "g:T" {
                        set value [::rl_json::json get $data @value]
                        return $value
                    }
                    }
                }
            } else {
                set jsontype [::rl_json::json type $data]
                if {[string compare $jsontype "string"] == 0} {
                        return [::rl_json::json get $data]
                } elseif {[string compare $jsontype "object"] == 0} {
                    set listresult [list]

                    set ovalue [rl_json::json get $data]
                    set keys [dict keys $ovalue]
                    foreach k $keys {
                        set v [rl_json::json extract $data $k]
                        set v2 [::GraphSON3Parser::parse $v]
                        lappend listresult [list $k $v2]
                    }

                    return $listresult
                } else {
                    return $data
                }
            }
        } else {
           set listresult [list]
           set value [::rl_json::json get $data]
           set length [llength $value]
           for {set i 0} {$i < $length} {incr i} {
               set v [::rl_json::json extract $data $i]
               set v2 [::GraphSON3Parser::parse $v]
               lappend listresult $v2
           }
           return $listresult
        }
    }
}
