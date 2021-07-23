tcl-gremlin
=====

It is a Gremlin Server driver for Tcl, and supports PLAIN 
SASL (username/password) authentication mechanism.

[Gremlin](https://tinkerpop.apache.org/gremlin.html) is the graph traversal 
language of [Apache TinkerPop](https://tinkerpop.apache.org/).

This package requires Tcl >= 8.6, TclOO, Tcllib websocket, Tcllib uuid,
rl_json and TclTLS package.

This project is under early development stage.


Example
=====

    package require GremlinClient

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
                puts $data
            } 
            204 {
                puts "NO CONTENT"
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

