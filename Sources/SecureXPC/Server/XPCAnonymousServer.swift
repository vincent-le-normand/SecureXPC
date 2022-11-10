//
//  XPCAnonymousServer.swift
//  SecureXPC
//
//  Created by Alexander Momchilov on 2021-11-28.
//

import Foundation

internal class XPCAnonymousServer: XPCServer {
    /// Receives new incoming connections
    private let anonymousListenerConnection: xpc_connection_t
    /// The dispatch queue used when new connections are being received
    private let listenerQueue = DispatchQueue(label: String(describing: XPCAnonymousServer.self))
    /// Whether this server has been started, if not connections are added to pendingConnections
    private var started = false
    /// Connections received while the server is not started
    private var pendingConnections = [xpc_connection_t]()
    
    internal override init(clientRequirement: XPCServer.ClientRequirement) {
        self.anonymousListenerConnection = xpc_connection_create(nil, listenerQueue)
        super.init(clientRequirement: clientRequirement)
        
        // Configure listener for new anonymous connections, all received events are incoming client connections
        xpc_connection_set_event_handler(self.anonymousListenerConnection, { connection in
            if self.started {
                self.startClientConnection(connection)
            } else {
                self.pendingConnections.append(connection)
            }
        })
        xpc_connection_resume(self.anonymousListenerConnection)
    }

    /// Begins processing requests received by this XPC server and never returns.
    public override func startAndBlock() -> Never {
        self.start()
        dispatchMain()
    }
    
    public override var connectionDescriptor: XPCConnectionDescriptor {
        .anonymous
    }
    
    public override var endpoint: XPCServerEndpoint {
        XPCServerEndpoint(connectionDescriptor: .anonymous,
                        endpoint: xpc_endpoint_create(self.anonymousListenerConnection))
    }

	/// Invalidate the connection.
	/// This is relevant for testing. The server is invalidated so no more connections are possible, simulate a crash of the server
	func invalidate() {
		self.started = false
		xpc_connection_cancel(anonymousListenerConnection)
	}
}

extension XPCAnonymousServer: XPCNonBlockingServer {
    public func start() {
        self.listenerQueue.sync {
            self.started = true
            for connection in self.pendingConnections {
                self.startClientConnection(connection)
            }
            self.pendingConnections.removeAll()
        }
    }
}
