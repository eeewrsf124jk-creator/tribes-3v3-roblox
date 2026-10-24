--!strict
-- Developer Product mapping. Developer Product IDs are created per-experience on the Creator
-- Dashboard (Monetization > Developer Products), so they cannot be known ahead of time.
-- Create one product per entry below with the listed Robux price, then paste its numeric ID
-- into ProductId. Entries left at 0 are reported as "not configured" and are never prompted.

export type ProductKind = "GoldenDrop" | "RestoreStreak" | "ItemUnlock" | "TribeCreation"

export type Product = {
	Key: string,
	Kind: ProductKind,
	ProductId: number,
	PriceRobux: number,
	DisplayName: string,
	-- RestoreStreak: highest streak this tier can restore. ItemUnlock: the RobuxCost tier.
	Tier: number?,
}

local Products: { Product } = {
	{ Key = "GoldenDrop", Kind = "GoldenDrop", ProductId = 0, PriceRobux = 9, DisplayName = "Golden Drop" },
	{
		Key = "RestoreStreakSmall",
		Kind = "RestoreStreak",
		ProductId = 0,
		PriceRobux = 20,
		DisplayName = "Restore Streak (1-4)",
		Tier = 4,
	},
	{
		Key = "RestoreStreakMedium",
		Kind = "RestoreStreak",
		ProductId = 0,
		PriceRobux = 39,
		DisplayName = "Restore Streak (5-9)",
		Tier = 9,
	},
	{
		Key = "RestoreStreakLarge",
		Kind = "RestoreStreak",
		ProductId = 0,
		PriceRobux = 79,
		DisplayName = "Restore Streak (10+)",
		Tier = math.huge,
	},
	{
		Key = "ItemUnlock399",
		Kind = "ItemUnlock",
		ProductId = 0,
		PriceRobux = 399,
		DisplayName = "Instant Unlock (Tier 1)",
		Tier = 399,
	},
	{
		Key = "ItemUnlock599",
		Kind = "ItemUnlock",
		ProductId = 0,
		PriceRobux = 599,
		DisplayName = "Instant Unlock (Tier 2)",
		Tier = 599,
	},
	{
		Key = "ItemUnlock799",
		Kind = "ItemUnlock",
		ProductId = 0,
		PriceRobux = 799,
		DisplayName = "Instant Unlock (Tier 3)",
		Tier = 799,
	},
	{ Key = "TribeCreation", Kind = "TribeCreation", ProductId = 0, PriceRobux = 299, DisplayName = "Found a Tribe" },
}

local MonetizationCatalog = {
	Products = Products,
	GoldenDropShards = 60,
}

function MonetizationCatalog.ByKey(key: string): Product?
	for _, p in Products do
		if p.Key == key then
			return p
		end
	end
	return nil
end

function MonetizationCatalog.ByProductId(productId: number): Product?
	if productId == 0 then
		return nil
	end
	for _, p in Products do
		if p.ProductId == productId then
			return p
		end
	end
	return nil
end

function MonetizationCatalog.IsConfigured(p: Product): boolean
	return p.ProductId > 0
end

function MonetizationCatalog.RestoreTierFor(streak: number): Product?
	local best: Product? = nil
	for _, p in Products do
		if p.Kind == "RestoreStreak" and p.Tier ~= nil and streak <= p.Tier then
			if best == nil or (p.Tier :: number) < (best.Tier :: number) then
				best = p
			end
		end
	end
	return best
end

function MonetizationCatalog.UnlockProductFor(robuxCost: number): Product?
	for _, p in Products do
		if p.Kind == "ItemUnlock" and p.Tier == robuxCost then
			return p
		end
	end
	return nil
end

return MonetizationCatalog
