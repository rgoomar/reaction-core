###################################################################################
#  i18next http://i18next.com/  Implementation for Reaction Commerce
#
#  usage - in template: {{i18n 'cartDrawer.empty'}}
#  usage - inline tag: <td data-i18n='cartSubTotals.items'>
#  usage - reference:  <thead data-i18n>cartSubTotals.head</thead>
#  usage - alerts Alerts.add "Message!", "danger", placement: "productDetail", i18n_key: "productDetail.outOfStock"
#
#  all translations should go in private/data/i18n/*.json, where they get imported into `Translations`
#  language keys fallback to English, and then template text.
#
###################################################################################

###
#
# get i18n messages for  updating autoform labels from simple schema
#
###
getLabelsFor = (schema, name, sessionLanguage) ->
  labels = {}
  for fieldName in schema._schemaKeys
    i18n_key = name.charAt(0).toLowerCase() + name.slice(1) + "." + fieldName.split(".$").join("")
    # console.log "schema:  " + name + "  fieldName:  " + fieldName + " i18nkey: " + i18n_key
    translation = i18n.t(i18n_key)
    if new RegExp('string').test(translation) isnt true and translation isnt i18n_key
      # schema._schema[fieldName].label =  i18n.t(i18n_key)
      labels[fieldName] = translation
  return labels

###
# get i18n messages for autoform messages
# currently using a globalMessage namespace only
#
# TODO: implement messaging hierarchy from simple-schema
#
# (1) Use schema-specific message for specific key
# (2) Use schema-specific message for generic key
# (3) Use schema-specific message for type
#
###
getMessagesFor = (schema, name, sessionLanguage) ->
  messages = {}
  for message of SimpleSchema._globalMessages
    i18n_key = "globalMessages" + "." + message
    translation = i18n.t(i18n_key)

    if new RegExp('string').test(translation) isnt true and translation isnt i18n_key
      messages[message] = translation
  return messages

###
#  set language and autorun on change of language
#  initialize i18n and load data resources for the current language and fallback 'EN'
#
###

Meteor.startup ->
  Session.set "language", i18n.detectLanguage()
  # initialize  templates
  _.each Template, (template, name) ->
  # for template,name of Template
    return if name?
    return if name is "prototype" or name.slice(0, 2) is "__"
    originalRender = template.rendered
    template.rendered = ->
      try @.$("[data-i18n]").i18n()
      originalRender and originalRender.apply(this, arguments)

Deps.autorun () ->
  sessionLanguage = Session.get "language"
  Meteor.subscribe "Translations", sessionLanguage, () ->
    resources =  ReactionCore.Collections.Translations.find({ $or: [{'i18n':'en'},{'i18n': sessionLanguage}] },{fields:{_id: 0},reactive:false}).fetch()
    # map multiple translations into i18next format
    resources = resources.reduce (x, y) ->
        x[y.i18n]= y.translation
        x
    , {}

    $.i18n.init {
      lng: sessionLanguage
      fallbackLng: 'en'
      ns: "core"
      resStore: resources
      # debug: true
      },(t)->
        # update labels and messages for autoform,schemas
        for schema, ss of ReactionCore.Schemas
          ss.labels getLabelsFor(ss, schema, sessionLanguage)
          ss.messages getMessagesFor(ss, schema, sessionLanguage)

        #re-init i18n
        $("[data-i18n]").i18n()



###
# i18n helper
# see: http://i18next.com/
# pass this the translation key as the first argument.
# optionally you can pass a string like "Invalid email", and we'll look for "invalidEmail"
# in the translations data.
#
# ex: {{i18n "accountsUI.error" "Invalid Email"}}
###
UI.registerHelper "i18n", (i18n_key, camelCaseString) ->
  unless i18n_key then Meteor.throw("i18n key string required to translate")
  if (typeof camelCaseString) is "string" then i18n_key = i18n_key + "." + camelCaseString.toCamelCase()
  result = new Handlebars.SafeString(i18n.t(i18n_key))
  return result


#default return $ symbol
UI.registerHelper "currency", () ->
  shops = Shops.findOne()
  if shops then return shops.currency

# return shop specific currency format
UI.registerHelper "currencySymbol", () ->
  shops = Shops.findOne()
  if shops then return shops.moneyFormat