#!/usr/bin/tclsh
#
# Is is a simple program to verify tcl-gremlin package
#

package require GremlinClient
package require GraphSON3Parser

set client [GremlinClient new ws://localhost:8182/gremlin]
try {
    $client connect
} on error {em} {
    puts $em
    exit
}

puts "Please input exit or quit to leave."
puts ""

while {1} {
    puts -nonewline stdout "Gremlin> "
    flush stdout
    gets stdin query

    switch $query {
        "exit" -
        "quit" {
            puts ""
            puts "Have a nice time, bye bye~~~"
            exit
        }
        default {
            try {
                set code [$client submit $query]
                if {$code==407} {
                    set code [$client authentication]
                }

                switch $code {
                    200 {
                        set data [$client getData]

                        # Try to parse data
                        puts ""
                        puts "===> [::GraphSON3Parser::parse $data]"
                    } 
                    204 {
                        puts "NO CONTENT"
                    }
                    206 {
                        set data [$client getData]
                        set parsedata [::GraphSON3Parser::parse $data]
                        while {$code!=200} {
                            set code [$client getReceived]
                            set moredata [$client getData]
                            set moreparsedata [::GraphSON3Parser::parse $moredata]
                            append parsedata $moreparsedata
                        }

                        puts ""
                        puts "===> $parsedata"
                    }
                    401 {
                        puts "UNAUTHORIZED"
                    }
                }
            } on error {em} {
                puts "Error: $em"
            }
        }
    }
}

$client disconnect
$client destroy

