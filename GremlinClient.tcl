#
# A Gremlin Server driver for Tcl.
# Gremlin client in Tcl for the WebSocketChannelizer.
#
package require Tcl 8.6
package require TclOO
package require websocket
package require uuid
package require rl_json
package require tls

package provide GremlinClient 0.1

set DEBUG 0

#
# Websocker handler
#
namespace eval ::GremlinClient {
    variable connected
    variable received
    variable message

    proc handler { sock type msg } {
        switch -glob -nocase -- $type {
            co* {
                if {$::DEBUG} {
                    puts "Connected on $sock"
                }

                set ::GremlinClient::connected 1
            }
            bi* {
                if {$::DEBUG} {
                    puts "RECEIVED: $msg"
                }

                set ::GremlinClient::message $msg
                set ::GremlinClient::received 1
            }
            cl* -
            dis* {
            }
        }
    }
}


oo::class create GremlinClient {
    variable url
    variable username
    variable password
    variable sock
    variable params
    variable requestId
    variable sessionId

    constructor {URL {USERNAME ""} {PASSWORD ""}} {
        set url $URL
        set username $USERNAME
        set password $PASSWORD
        set sock {}
        set params [dict create]
        set requestId {}
        set sessionId {}

        # for WebSockets over TLS
        http::register https 443 [list ::tls::socket -ssl2 0 -ssl3 0 -tls1 1 -tls1.1 1 -tls1.2 1]
    }

    destructor {
        if {[string compare [my isConnected] "CONNECTED"]==0} {
            my disconnect
        }
    }

    method connect {} {
        set sock [::websocket::open $url ::GremlinClient::handler -timeout 3000]
        set ::GremlinClient::connected 0

        # To handle connect failed then wait forever case
        after 3000 [list apply {{varName} {
            if {![set $varName]} {
                set $varName 0
            }
        }} ::GremlinClient::connected]

        vwait ::GremlinClient::connected

        if {[string compare [my isConnected] "CONNECTED"]!=0} {
            error "Connect failed"
        }
        return ok
    }

    method isConnected {} {
       # If we get state failed, then return CLOSED state.
       try {
           set state [::websocket::conninfo $sock state]
       } on error {em} {
           set state "CLOSED"
       } finally {
           return $state
       }
    }

    method disconnect {} {
        try {
            if {[my isSessionOpen]==1} {
                my closeSession
            }

            ::websocket::close $sock 1000
        } finally {
            set sock {}
        }
    }

    method param {key value} {
        dict set params $key $value
    }

    method genRequest {script} {
        variable id
        variable msg
        variable mimetype
        variable length
        variable finalmsg
        variable paramvalue
        variable paramlist
        variable paramstring

        set paramlist [list]
        foreach {key value} $params {
            set paramvalue [join [list $key $value] ":"]
            lappend paramlist $paramvalue
        }

        set paramstring [join $paramlist ","]
        set paramstring [concat "{" $paramstring "}"]

        set id [::uuid::uuid generate]
        set requestId $id
        set mimetype "application/json"
        set length [binary format c [string length $mimetype]]
        try {
            if {[my isSessionOpen]==0} {
                set msg  [::rl_json::json template {{"requestId":"~S:id",
                "op":"eval",
                "processor":"",
                "args":{"gremlin":"~S:script",
                        "bindings":"~T:paramstring",
                        "language":"gremlin-groovy"}
                    }} [list id $id script $script paramstring $paramstring]]
            } else {
                set msg  [::rl_json::json template {{"requestId":"~S:id",
                "op":"eval",
                "processor":"session",
                "args":{"gremlin":"~S:script",
                        "session" :"~S:sessionId",
                        "bindings":"~T:paramstring",
                        "language":"gremlin-groovy"}
                    }} [list id $id script $script sessionId $sessionId paramstring $paramstring]]
            }

            set finalmsg [string cat $length $mimetype $msg]
        } on error {em} {
            error $em
        }

        return $finalmsg
    }

    method genAuthRequest {} {
        variable id
        variable msg
        variable mimetype
        variable length
        variable finalmsg
        variable authmessage

        set authmessage [binary encode base64 [format %c 0]$username[format %c 0]$password]

        set id [::uuid::uuid generate]
        # Response is for the original request, so not setup requestId again

        set mimetype "application/json"
        set length [binary format c [string length $mimetype]]
        try {
            set msg  [::rl_json::json template {{"requestId":"~S:id",
              "op":"authentication",
              "processor":"",
              "args":{"@type" : "g:Map",
                      "@value" : [ "saslMechanism", "PLAIN", "sasl", "~S:authmessage" ]
                     }
                   }} [list id $id authmessage $authmessage]]
            set finalmsg [string cat $length $mimetype $msg]
        } on error {em} {
            error $em
        }

        return $finalmsg
    }

    method genCloseSessionRequest {} {
        variable id
        variable msg
        variable mimetype
        variable length
        variable finalmsg

        set id $requestId
        set mimetype "application/json"
        set length [binary format c [string length $mimetype]]
        try {
            set msg  [::rl_json::json template {{"requestId":"~S:id",
              "op":"close",
              "processor":"session",
              "args" : {
                  "session" : "~S:sessionId"
                    }
                   }} [list id $id sessionId $sessionId]]
            set finalmsg [string cat $length $mimetype $msg]
        } on error {em} {
            error $em
        }

        return $finalmsg
    }

    method send {finalmsg} {
       variable code

       try {
           ::websocket::send $sock binary $finalmsg
       } on error {em} {
           error "send failed: $em"
       } finally {
           # Clear params
           set params [dict create]
       }

       try {
           set code [my getReceived]
       } on error {em} {
           error $em
       }

       return $code
    }

    method submit {script} {
        variable finalmsg
        variable code

        if {[string compare [my isConnected] "CONNECTED"]!=0} {
            error "Not CONNECTED state"
        } else {
            # Setup our message variable
            set ::GremlinClient::message ""

            try {
                set finalmsg [my genRequest $script]
                set code [my send $finalmsg]
                return $code
            } on error {em} {
                error $em
            }
        }
    }

    method authentication {} {
        variable finalmsg
        variable code

        if {[string compare [my isConnected] "CONNECTED"]!=0} {
            error "Not CONNECTED state"
        } else {
            # Setup our message variable
            set ::GremlinClient::message ""

            try {
                set finalmsg [my genAuthRequest]
                set code [my send $finalmsg]
                return $code
            } on error {em} {
                error $em
            }
        }
    }

    method getReceived {} {
        variable code

        set ::GremlinClient::received 0
        after 3000 [list apply {{varName} {
            if {![set $varName]} {
                set $varName 0
            }
        }} ::GremlinClient::received]
        vwait ::GremlinClient::received

        set message $::GremlinClient::message
        if {[string length message]==0} {
            error "No data"
        }

        set rId [::rl_json::json get $message requestId]
        if {[string compare $requestId $rId]} {
            error "Invalid requestId"
        }

        set code [::rl_json::json get $message status code]
        return $code
    }

    method getData {} {
        variable data

        set message $::GremlinClient::message
        if {[string length message]==0} {
            error "No data"
        }

        set data [::rl_json::json extract $message result data]
        return $data
    }

    method getSession {} {
        set sessionId [::uuid::uuid generate]
    }

    method isSessionOpen {} {
        if {[string length $sessionId] > 0} {
            return 1
        }

        return 0
    }

    method closeSession {} {
        variable finalmsg
        variable code

        if {[my isSessionOpen]==1} {
            if {[string compare [my isConnected] "CONNECTED"]!=0} {
                error "Not CONNECTED state"
            } else {
                # Setup our message variable
                set ::GremlinClient::message ""

                try {
                    set finalmsg [my genCloseSessionRequest]
                    set code [my send $finalmsg]

                    return $code
                } on error {em} {
                    error $em
                }
            }
        }

        set sessionId {}
    }
}
