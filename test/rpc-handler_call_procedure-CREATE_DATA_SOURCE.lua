package.path = "../?.lua;" .. package.path

require 'busted.runner'()

local match = require("luassert.match")
local _ = match._

describe("impl.rpc-handler", function()
  
  local qlua = require("qlua.api")
  local sut = require("impl.rpc-handler")

  describe("WHEN given a request of type ProcedureType.CREATE_DATA_SOURCE", function()
      
    local request
    
    setup(function()
      
      request = {}
      request.type = qlua.RPC.ProcedureType.CREATE_DATA_SOURCE
    end)
  
    teardown(function()
      request = nil
    end)

    describe("WITH arguments", function()
        
      local request_args
      local proc_result
      
      setup(function()

        request_args = qlua.datasource.CreateDataSource.Request()
        request_args.class_code = "test-class_code"
        request_args.sec_code = "test-sec_code"

        proc_result = {a = 0, b = "b", c = {}} -- let's pretend that this is a DataSource instance
      end)

      teardown(function()

        request_args = nil
        proc_result = nil
      end)
    
      describe("WHERE the argument 'interval'", function()
          
        insulate("IS Interval.UNDEFINED", function()
            
          setup(function()
            request_args.interval = qlua.datasource.CreateDataSource.Interval.UNDEFINED
            request.args = request_args:SerializeToString()
          end)
        
          teardown(function()
            request_args.interval = qlua.datasource.CreateDataSource.Interval.INTERVAL_M5
            request.args = request_args:SerializeToString()
          end)
        
          it("SHOULD raise an error", function()
            assert.has_error(function() sut.call_procedure(request.type, request.args) end, "Unknown interval type.")  
          end)
        end)
      
        describe("IS NOT Interval.UNDEFINED", function()
            
          local uuid_result, utils, corresponding_qlua_interval
          
          setup(function()
              
            request_args.interval = qlua.datasource.CreateDataSource.Interval.INTERVAL_M5
            request.args = request_args:SerializeToString()
            
            uuid_result = "test-uuid"
            corresponding_qlua_interval = 123
            
            utils = require("utils.utils")
            utils.to_interval = spy.new(function(pb_interval) return corresponding_qlua_interval end)
            
            _G.uuid = spy.new(function() return uuid_result end)
            _G.CreateDataSource = spy.new(function(class_code, sec_code, interval, param) return proc_result end)
          end)
        
          teardown(function()
            uuid_result = nil
            utils = nil
          end)
        
          it("SHOULD call the global 'uuid' function once", function()
                  
            local response = sut.call_procedure(request.type, request.args)
            
            assert.spy(_G.uuid).was_called(1)
          end)
        
          it("SHOULD contain the procedure result in the 'datasources' table mapped by the 'uuid' function's result", function()
                  
            local response = sut.call_procedure(request.type, request.args)
            
            assert.are.equal(sut.datasources[uuid_result], proc_result)
          end)
        
          it("SHOULD return a qlua.datasource.CreateDataSource.Result instance", function()
        
            local actual_result = sut.call_procedure(request.type, request)
            local expected_result = qlua.datasource.CreateDataSource.Result()

            local actual_meta = getmetatable(actual_result)
            local expected_meta = getmetatable(expected_result)

            assert.are.equal(expected_meta, actual_meta)
          end)
        
          it("SHOULD return a protobuf object which string-serialized form equals to that of the expected result", function()
          
            local actual_result = sut.call_procedure(request.type, request)
            local expected_result = qlua.datasource.CreateDataSource.Result()
            expected_result.datasource_uuid = uuid_result
            
            assert.are.equal(expected_result:SerializeToString(), actual_result:SerializeToString())
          end)
      
          describe("AND the argument 'param'", function()
              
            insulate("IS an empty string", function()
                
              setup(function()
                  
                request_args.param = ""
                request.args = request_args:SerializeToString()
                
                _G.CreateDataSource = spy.new(function(class_code, sec_code, interval) return proc_result end)
              end)
            
              it("SHOULD call the global 'CreateDataSource' function once with 3 arguments: class_code, sec_code and the corresponding QLua interval", function()
                  
                local response = sut.call_procedure(request.type, request.args)
                
                assert.spy(_G.CreateDataSource).was.called_with(request_args.class_code, request_args.sec_code, corresponding_qlua_interval)
              end)
            
              insulate("AND the global 'CreateDataSource' returns nil and some text", function()
                
                local error_desc
                
                setup(function()
                    
                  error_desc = "test-error_desc"
                  _G.CreateDataSource = spy.new(function(class_code, sec_code, interval) return nil, error_desc end)
                end)
              
                teardown(function()
                  error_desc = nil
                end)
              
                it("SHOULD raise an error", function()
                    
                  local expected_error_msg = string.format("Процедура CreateDataSource(%s, %s, %d) возвратила nil и сообщение об ошибке: [%s].", request_args.class_code, request_args.sec_code, corresponding_qlua_interval, error_desc)
        
                  assert.has_error(
                    function() sut.call_procedure(request.type, request.args) end, expected_error_msg)
                end)
              end)
            end)
          
            insulate("IS NOT an empty string", function()
                
              setup(function()
                  
                request_args.param = "test-param"
                request.args = request_args:SerializeToString()
                
                _G.CreateDataSource = spy.new(function(class_code, sec_code, interval, param) return proc_result end)
              end)
            
              it("SHOULD call the global 'CreateDataSource' function once with 4 arguments: class_code, sec_code, the corresponding QLua interval, param", function()
                  
                local response = sut.call_procedure(request.type, request.args)
                
                assert.spy(_G.CreateDataSource).was.called_with(request_args.class_code, request_args.sec_code, corresponding_qlua_interval, request_args.param)
              end)
            
              insulate("AND the global 'CreateDataSource' returns nil and some text", function()
                
                local error_desc
                
                setup(function()
                    
                  error_desc = "test-error_desc"
                  _G.CreateDataSource = spy.new(function(class_code, sec_code, interval, param) return nil, error_desc end)
                end)
              
                teardown(function()
                  error_desc = nil
                end)
              
                it("SHOULD raise an error", function()
                    
                  local expected_error_msg = string.format("Процедура CreateDataSource(%s, %s, %d, %s) возвратила nil и сообщение об ошибке: [%s].", request_args.class_code, request_args.sec_code, corresponding_qlua_interval, request_args.param, error_desc)
        
                  assert.has_error(function() sut.call_procedure(request.type, request.args) end, expected_error_msg)
                end)
              end)
            end)
          end)
        end)
      end)
    end)
  
    describe("WITHOUT arguments", function()
      
      it("SHOULD raise an error", function()
        
        assert.has_error(function() sut.call_procedure(request.type) end, "The request has no arguments.")
      end)
    end)
  end)

end)
