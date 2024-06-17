local M = {}
M.count = 0

function M.get_tests()
	local uv = vim.uv
	local server = uv.new_tcp()
	server:bind("127.0.0.1", 10043) -- Set the port to 0, so it will bind to an available port
	server:listen(128, function(err)
		assert(not err, err)
		local client = uv.new_tcp()
		server:accept(client)
		client:read_start(function(err, chunk)
			assert(not err, err)
			if chunk then
				local re = vim.regex('{"name"')
				local string = require("string")
				local start_index, _ = re:match_str(chunk)
				local data = vim.json.decode(string.sub(chunk, start_index))
				local tests = data["tests"]
				os.execute("rm /tmp/code*")
				os.execute("rm /tmp/output")
				M.count = #tests
				for i = 1, #tests do
					for k, v in pairs(tests[i]) do
						-- vim.notify(v)
						local fp = assert(io.open("/tmp/code_" .. i .. "_" .. k, "w+"))
						fp:write(v)
						fp:close()
					end
				end
				client:write(chunk)
				vim.notify("GetTests Done!")
			else
				client:shutdown()
				client:close()
			end
		end)
	end)
	vim.notify("Ready to get tests")
	uv.run("nowait")
end


function M.setup()
	vim.api.nvim_create_user_command("GetTests", function()
		pcall(function()
			M.get_tests()
		end)
	end, {})
	vim.api.nvim_create_user_command("RunCodeTest", function()
		M.valid()
	end, {})
	-- vim.notify("hello")
	-- get_teset()
end

return M
