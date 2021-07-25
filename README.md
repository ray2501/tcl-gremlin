tcl-gremlin
=====

It is a Gremlin Server driver for Tcl, and supports PLAIN 
SASL (username/password) authentication mechanism.

[Gremlin](https://tinkerpop.apache.org/gremlin.html) is the graph traversal 
and query language of [Apache TinkerPop](https://tinkerpop.apache.org/).
Apache TinkerPop is a graph computing framework for both graph databases 
(OLTP) and graph analytic systems (OLAP).

This package requires [Tcl](https://www.tcl.tk/) >= 8.6, 
TclOO, Tcllib websocket, Tcllib uuid,
[rl_json](https://github.com/RubyLane/rl_json) and 
[TclTLS](https://core.tcl-lang.org/tcltls/home) package.


Example
=====

Connection:

    package require GremlinClient
    package require GraphSON3Parser

    set client [GremlinClient new ws://localhost:8182/gremlin]
    #set client [GremlinClient new wss://localhost:8182/gremlin "user" "passwd"]
    try {
        $client connect
        $client param {"x"} 1
        set code [$client submit "g.V(x).out()"]
        if {$code==407} {
            set code [$client authentication]
        }

        switch $code {
            200 {
                set data [$client getData]

                # Try to parse data
                puts [::GraphSON3Parser::parse $data]
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

                puts $parsedata
            }
            401 {
                puts "UNAUTHORIZED"
            }
        }

        $client disconnect
    } on error {em} {
        puts "Error: $em"
    } finally {
        $client destroy
    }

Gremlin Server supports sessions. With sessions, the user is in complete 
control of the start and end of the transaction. I try to add related
methods but I am not sure it is done.

    package require GremlinClient
    package require GraphSON3Parser

    set client [GremlinClient new ws://localhost:8182/gremlin]
    try {
        $client connect
        $client getSession
        set code [$client submit "g.V().count()"]
        switch $code {
            200 {
                set data [$client getData]
                puts "Vertices: [::GraphSON3Parser::parse $data]"
            }
            204 {
                puts "NO CONTENT"
            }
        }

        set code [$client submit "g.E().count()"]
        switch $code {
            200 {
                set data [$client getData]
                puts "Edges: [::GraphSON3Parser::parse $data]"
            }
            204 {
                puts "NO CONTENT"
            }
        }

        $client closeSession
        $client disconnect
    } on error {em} {
        puts "Error: $em"
    } finally {
        $client destroy
    }

