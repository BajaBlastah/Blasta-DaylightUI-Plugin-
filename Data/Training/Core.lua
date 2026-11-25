local _, extras = ...
local classes = {}

extras.TrainingData = {
    classes = classes,
    gameVersion = "forever",
    locale = GetLocale(),
    forClass = function(token)
        if not classes[token] then classes[token] = {} end
        return classes[token]
    end,
}
