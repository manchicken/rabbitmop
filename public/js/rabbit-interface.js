/*
 * This is the RabbitMop interface.
 */

const _DEBUG_ = console.log

/**
 * @param  {String} field        The ID value of the field
 * @param  {String} defaultValue The default value to return
 * @return {String} Returns the value of the field, or the default value
 */
const $f = (field, defaultValue) => (!!document.getElementById(field)) ?
	document.getElementById(field).value :
	defaultValue

function RabbitUI() {
	let self = this

	/**
	 * @return {Boolean} Returns true if we're waiting for something else.
	 */
	self.isWaiting = () => !!iface.isWorking()

	/**
	 * This function will tell the user to wait.
	 * @return {Boolean} Returns true if we're waiting
	 */
	self.blockForWait = () => {
		if (self.isWaiting()) {
			alert("RabbitMop is working, please continue waiting.")
			return true
		}

		return false
	}

	/**
	 * Using the WebSocket, authenticate with RabbitMQ.
	 * @param  {Object} $_ The parameters to use when authenticating
	 */
	self.authenticate = function authenticate($_) {
		if (self.blockForWait()) return

		const authArgs = {
			host: $f('field.host', null),
			port: $f('field.port', null),
			vhost: $f('field.vhost', null),
			username: $f('field.username', null),
			password: $f('field.password', null),
		}
		_DEBUG_("Conn args" + JSON.stringify(authArgs))

		iface.send(authArgs)
	}
}

/*
 * The primary interface
 */
function RabbitInterface() {
	let self = this

	// A little warning for browser support...
	if (! window.Worker ) {
		alert("You can't use this browser with this application. Web Worker API support is required.")
		throw new Error("Unsupported browser (missing WebWorker API)")
	}

	self.working = true

	/**
	 * @return {Boolean}
	 */
	self.isWorking = () => !!self.working

	/*
	 * Establish a connection with the web worker, and just verify that the
	 * thread is established.
	 */
	self.workerInit = function workerInit ($_) {
		self.working = true
		self.worker = new Worker('js/rabbit-interface-worker.js')
		self.worker.onmessage=self.messageHandler
		self.worker.onerror=self.errorHandler

		self.worker.postMessage({message:'init', args:{greeting:'Hiya'}})
	}

	/**
	 * @param  {Event} eventInstance
	 * @return {null}
	 */
	self.messageHandler = function messageHandler(eventInstance) {
		const message=eventInstance.data.message
		const args=eventInstance.data.args

		if (self.messageDefinitions.hasOwnProperty(message)) {
			return self.messageDefinitions[message](args)
		}

		console.error('No such message defined: ', message)
	}

	/**
	 * Definitions of various messages.
	 * @type {Object}
	 */
	self.messageDefinitions = {
		initAck: function message_initAck($_) {
			_DEBUG_('Worker init acknowledged: ', $_.greeting)
			self.working = false
			queue.start()
		},

		connectAck: function message_connectAck($_) {
			_DEBUG_('Connection complete!')
			self.working = false
		}
	}

	/**
	 * @param  {String} url
	 * @return {[type]}
	 */
	self.connect = function connect(url) {
		self.worker.postMessage({message:'connect',args:url})
		self.working = false
	}

	self.queue = function queue(func, $_) {

	} 
}

function Queuer() {
	let self = this

	const queueTimer = 0.5 * 1000

	self.items = []
	self.runningOne = false

	self.start = function start() {
		setTimeout(self.start, queueTimer)
		if (self.items.length > 0) self.runNext()
	}

	self.runNext = function runNext() {
		_DEBUG_("TICK: PARENT")
		if (self.runningOne) return
		const nextItem = self.items.pop()
		nextItem()
		self.runningOne = false
	}

	self.queue = function queue(func) {
		self.items.push(func)
	}
}

const iface = new RabbitInterface()
const ui = new RabbitUI()
const queue = new Queuer()

// Stuff to run...
iface.workerInit()
