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
						local fp = assert(io.open("/tmp/code_" .. i .. "_" .. k, "w"))
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

function M.valid()
	local current_file = vim.fn.expand("%")
	os.execute("g++ " .. current_file .. " --std=c++11 -o out ")
	if M.count == 0 then
		local handle = io.popen("ls -la /tmp/ | grep input | wc -l")
		local result = assert(handle:read("*a"))
		handle:close()
		str = result:gsub("%s+", "")
		M.count = tonumber(str)
	end
	-- vim.print(M.count)
	local count = 0
	local result = ""
	local fpresult = assert(io.open("/tmp/output", "w"))
	for i = 1, M.count do
		os.execute("./out < /tmp/code_" .. i .. "_input > /tmp/code_" .. i .. "_test")
		local fpoutput = assert(io.open("/tmp/code_" .. i .. "_output", "r"))
		local fptest = assert(io.open("/tmp/code_" .. i .. "_test", "r"))
		local output = {}
		local test = {}
		for line in fpoutput:lines() do
			output[#output] = line
		end

		for line in fptest:lines() do
			test[#test] = line
		end
		if #output == #test then
			local subCount = 0
			local subTotal = 0
			for j = 0, #output do
				subTotal = subTotal + 1
				output[j] = output[j]:gsub("%s+", "")
				test[j] = test[j]:gsub("%s+", "")
				result = result .. output[j] .. " " .. test[j]
				if output[j] == test[j] then
					subCount = subCount + 1
					result = result .. " Correct! \n"
				else
					result = result .. " Wrong! \n"
				end
			end
			result = result .. "\n"
			if subCount == subTotal then
				count = count + 1
				result = result .. "SubTest " .. i .. " PASSED!\n"
			else
				result = result .. "SubTest " .. i .. " FAILED!\n"
			end
			result = result .. "\n\n"
		end
	end
	if M.count == count then
		result = result .. "Test PASSED!\n"
	else
		result = result .. "Test FAILED!\n"
	end
	fpresult:write(result)
	fpresult:close()
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
