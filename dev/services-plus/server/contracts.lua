local raw = LoadResourceFile(GetCurrentResourceName(), "shared/api_contracts.json")
local ok, contracts = pcall(json.decode, raw or "")

if not ok or type(contracts) ~= "table" or contracts.version ~= ServicesPlus.Constants.ApiVersion then
    error("Services+ API contract metadata is missing, invalid, or has the wrong version")
end

ServicesPlus.Contracts = contracts
