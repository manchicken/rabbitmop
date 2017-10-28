/*
 * This is the RabbitMop interface's WebWorker.
 */

const keepaliveTimer=10*1000

const _DEBUG_ = console.log
const valueOrException = (props, key, message) => {
	if (props.hasOwnProperty(key)) return props[key]

	throw new Error(message)
}

function RabbitConnection({delegate}) {
	let self = this
	self.delegate = delegate

	self.connect = function connect(url) {
		self.socket = new WebSocket(url)
		self.socket.addEventListener('open', self.onOpen)
		self.socket.addEventListener('message', self.onMessage)
		return true
	}

	// Socket is open
	self.onOpen = function onOpen(event) {
		self.delegate.delegateAction({action:'socketDidOpen', args:event})

		// Set the keepalive timer
		setTimeout(self.sendKeepalive, keepaliveTimer)
	}

	self.onMessage = function onMessage(event) {
		_DEBUG_("MESSAGE RECEIVED! "+JSON.stringify(event))
		self.delegateAction({action:'socketDidReceiveMessage', args:event})
	}

	// Send a keepalive packet, then loop.
	self.sendKeepalive = function sendKeepalive() {
		_DEBUG_("KEEP ALIVE")
		self.socket.send('{"action":"keepalive"}')
		setTimeout(self.sendKeepalive, keepaliveTimer)
	}

	self.authenticate = function authenticate($_) {
		self.socket.send(JSON.stringify($_))
	}
}

function RabbitInterfaceWorker() {
	let self = this

	self.respond = function respond($_) {
		const message = $_.message

		if (!message) return

		postMessage({message, args:$_})
	}

	/*
	 * Message event handler.
	 */
	self.workerMessager = function workerMessager(eventInstance) {
		const message=eventInstance.data.message
		const args=eventInstance.data.args

		if (self.workerMessageDefinitions.hasOwnProperty(message)) {
			return self.workerMessageDefinitions[message](args)
		}

		console.error('No such message defined: ', message)
	}

	self.delegateAction = function delegateAction({action, args={}}) {
		(
			self.delegateActionDefinitions[action]
			||
			function() {console.error('No such action: '+action)}
		)(args)
	}

	self.workerMessageDefinitions = {
		init: function message_init($_) {
			_DEBUG_('Worker configured and running: ', $_.greeting)
			self.respond({message:'initAck', greeting:$_.greeting})
		},

		connect: function message_connect(url) {
			self.connector = new RabbitConnection({delegate:self})
			self.respond({
				message:'connectAck',
				result:self.connector.connect(url)
			})
		},
	}

	self.delegateActionDefinitions = {
		socketDidOpen: function delegate_socketDidOpen($_) {
			_DEBUG_('Successfully opened socket.')
		},
	}
}

const ifaceWorker = new RabbitInterfaceWorker()

onmessage=ifaceWorker.workerMessager