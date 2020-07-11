if typeof process isnt 'undefined' and process.execPath and process.execPath.match /node|iojs/
  chai = require 'chai' unless chai
  noflo = require '../src/lib/NoFlo'
else
  noflo = require 'noflo'

describe 'Outport Port', ->
  describe 'with addressable ports', ->
    s1 = s2 = s3 = null
    beforeEach ->
      s1 = new noflo.internalSocket.InternalSocket
      s2 = new noflo.internalSocket.InternalSocket
      s3 = new noflo.internalSocket.InternalSocket

      return
    it 'should be able to send to a specific port', ->
      p = new noflo.OutPort
        addressable: true
      p.attach s1
      p.attach s2
      p.attach s3
      chai.expect(p.listAttached()).to.eql [0, 1, 2]
      s1.on 'data', ->
        chai.expect(true).to.equal false
        return
      s2.on 'data', (data) ->
        chai.expect(data).to.equal 'some-data'
        return
      s3.on 'data', ->
        chai.expect(true).to.equal false
        return
      p.send 'some-data', 1

      return
    it 'should be able to send to index 0', (done) ->
      p = new noflo.OutPort
        addressable: true
      p.attach s1
      s1.on 'data', (data) ->
        chai.expect(data).to.equal 'my-data'
        done()
        return
      p.send 'my-data', 0

      return
    it 'should throw an error when sent data without address', ->
      chai.expect(-> p.send('some-data')).to.throw

      return
    it 'should throw an error when a specific port is requested with non-addressable port', ->
      p = new noflo.OutPort
      p.attach s1
      p.attach s2
      p.attach s3
      chai.expect(-> p.send('some-data', 1)).to.throw

      return
    it 'should give correct port index when detaching a connection', (done) ->
      p = new noflo.OutPort
        addressable: true
      p.attach s1, 3
      p.attach s2, 1
      p.attach s3, 5
      expectedSockets = [s2, s3]
      expected = [1, 5]
      expectedAttached = [
        [3, 5]
        [3]
      ]
      p.on 'detach', (socket, index) ->
        chai.expect(socket).to.equal expectedSockets.shift()
        chai.expect(index).to.equal expected.shift()
        chai.expect(p.isAttached(index)).to.equal false
        atts = expectedAttached.shift()
        chai.expect(p.listAttached()).to.eql atts
        for att in atts
          chai.expect(p.isAttached(att)).to.equal true
        done() unless expected.length
        return
      p.detach s2
      p.detach s3
      return
    return
  describe 'with caching ports', ->
    s1 = s2 = s3 = null
    beforeEach ->
      s1 = new noflo.internalSocket.InternalSocket
      s2 = new noflo.internalSocket.InternalSocket
      s3 = new noflo.internalSocket.InternalSocket

      return
    it 'should repeat the previously sent value on attach event', (done) ->
      p = new noflo.OutPort
        caching: true

      s1.once 'data', (data) ->
        chai.expect(data).to.equal 'foo'
        return
      s2.once 'data', (data) ->
        chai.expect(data).to.equal 'foo'
        # Next value should be different
        s2.once 'data', (data) ->
          chai.expect(data).to.equal 'bar'
          done()
          return
        return
      p.attach s1
      p.send 'foo'
      p.disconnect()

      p.attach s2

      p.send 'bar'
      p.disconnect()


      return
    it 'should support addressable ports', (done) ->
      p = new noflo.OutPort
        addressable: true
        caching: true

      p.attach s1
      p.attach s2

      s1.on 'data', ->
        chai.expect(true).to.equal false
        return
      s2.on 'data', (data) ->
        chai.expect(data).to.equal 'some-data'
        return
      s3.on 'data', (data) ->
        chai.expect(data).to.equal 'some-data'
        done()
        return

      p.send 'some-data', 1
      p.disconnect 1
      p.detach s2
      p.attach s3, 1
      return
    return
  describe 'with IP objects', ->
    s1 = s2 = s3 = null
    beforeEach ->
      s1 = new noflo.internalSocket.InternalSocket
      s2 = new noflo.internalSocket.InternalSocket
      s3 = new noflo.internalSocket.InternalSocket

      return
    it 'should send data IPs and substreams', (done) ->
      p = new noflo.OutPort
      p.attach s1
      expectedEvents = [
        'data'
        'openBracket'
        'data'
        'closeBracket'
      ]
      count = 0
      s1.on 'ip', (data) ->
        count++
        chai.expect(data).to.be.an 'object'
        chai.expect(data.type).to.equal expectedEvents.shift()
        chai.expect(data.data).to.equal 'my-data' if data.type is 'data'
        done() if count is 4
        return
      p.data 'my-data'
      p.openBracket()
      .data 'my-data'
      .closeBracket()

      return
    it 'should send non-clonable objects by reference', (done) ->
      p = new noflo.OutPort
      p.attach s1
      p.attach s2
      p.attach s3

      obj =
        foo: 123
        bar:
          boo: 'baz'
        func: -> this.foo = 456

      s1.on 'ip', (data) ->
        chai.expect(data).to.be.an 'object'
        chai.expect(data.data).to.equal obj
        chai.expect(data.data.func).to.be.a 'function'
        s2.on 'ip', (data) ->
          chai.expect(data).to.be.an 'object'
          chai.expect(data.data).to.equal obj
          chai.expect(data.data.func).to.be.a 'function'
          s3.on 'ip', (data) ->
            chai.expect(data).to.be.an 'object'
            chai.expect(data.data).to.equal obj
            chai.expect(data.data.func).to.be.a 'function'
            done()
            return
          return
        return

      p.data obj,
        clonable: false # default

      return
    it 'should clone clonable objects on fan-out', (done) ->
      p = new noflo.OutPort
      p.attach s1
      p.attach s2
      p.attach s3

      obj =
        foo: 123
        bar:
          boo: 'baz'
        func: ->
          this.foo = 456
          return

      s1.on 'ip', (data) ->
        chai.expect(data).to.be.an 'object'
        # First send is non-cloning
        chai.expect(data.data).to.equal obj
        chai.expect(data.data.func).to.be.a 'function'
        s2.on 'ip', (data) ->
          chai.expect(data).to.be.an 'object'
          chai.expect(data.data).to.not.equal obj
          chai.expect(data.data.foo).to.equal obj.foo
          chai.expect(data.data.bar).to.eql obj.bar
          chai.expect(data.data.func).to.be.undefined
          s3.on 'ip', (data) ->
            chai.expect(data).to.be.an 'object'
            chai.expect(data.data).to.not.equal obj
            chai.expect(data.data.foo).to.equal obj.foo
            chai.expect(data.data.bar).to.eql obj.bar
            chai.expect(data.data.func).to.be.undefined
            done()
            return
          return
        return

      p.data obj,
        clonable: true

      return
    it 'should stamp an IP object with the port\'s datatype', (done) ->
      p = new noflo.OutPort
        datatype: 'string'
      p.attach s1
      s1.on 'ip', (data) ->
        chai.expect(data).to.be.an 'object'
        chai.expect(data.type).to.equal 'data'
        chai.expect(data.data).to.equal 'Hello'
        chai.expect(data.datatype).to.equal 'string'
        done()
        return
      p.data 'Hello'
      return
    it 'should keep an IP object\'s datatype as-is if already set', (done) ->
      p = new noflo.OutPort
        datatype: 'string'
      p.attach s1
      s1.on 'ip', (data) ->
        chai.expect(data).to.be.an 'object'
        chai.expect(data.type).to.equal 'data'
        chai.expect(data.data).to.equal 123
        chai.expect(data.datatype).to.equal 'integer'
        done()
        return
      p.sendIP new noflo.IP 'data', 123,
        datatype: 'integer'

      return
    it 'should stamp an IP object with the port\'s schema', (done) ->
      p = new noflo.OutPort
        datatype: 'string'
        schema: 'text/markdown'
      p.attach s1
      s1.on 'ip', (data) ->
        chai.expect(data).to.be.an 'object'
        chai.expect(data.type).to.equal 'data'
        chai.expect(data.data).to.equal 'Hello'
        chai.expect(data.datatype).to.equal 'string'
        chai.expect(data.schema).to.equal 'text/markdown'
        done()
        return
      p.data 'Hello'
      return
    it 'should keep an IP object\'s schema as-is if already set', (done) ->
      p = new noflo.OutPort
        datatype: 'string'
        schema: 'text/markdown'
      p.attach s1
      s1.on 'ip', (data) ->
        chai.expect(data).to.be.an 'object'
        chai.expect(data.type).to.equal 'data'
        chai.expect(data.data).to.equal 'Hello'
        chai.expect(data.datatype).to.equal 'string'
        chai.expect(data.schema).to.equal 'text/plain'
        done()
        return
      p.sendIP new noflo.IP 'data', 'Hello',
        datatype: 'string'
        schema: 'text/plain'
      return
    return
  return
