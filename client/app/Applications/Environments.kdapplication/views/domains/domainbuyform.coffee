class DomainBuyForm extends CommonDomainCreateForm

  constructor:(options = {}, data)->
    super
      placeholder : "Type your awesome domain..."
    , data

    @availableDomainsList = new KDListViewController
      itemClass : DomainBuyItem

    @domainListView = @availableDomainsList.getView()
                      .setClass 'domain-list'

    listView = @availableDomainsList.getListView()
    listView.on 'BuyButtonClicked', (item) =>
      {price, domain} = item.getData()
      year = +item.yearBox.getValue()
      fmtPrice = @utils.formatMoney year * price
      modal = new DomainBuyModal
        domain      : domain
        productForm : new DomainProductForm
        confirmForm : new DomainBuyConfirmForm { domain, year, price: fmtPrice }

      modal.on 'PaymentConfirmed', ({ productData, paymentMethodId }) =>
        @buyDomain { domain, year, price, paymentMethodId, productData }

  buyDomain: (options) ->
    { JPaymentCharge } = KD.remote.api

    { price, paymentMethodId, productData: address, year, domain } = options
    
    feeAmount = price * 100 # cents

    JPaymentCharge.charge { feeAmount, paymentMethodId }, (err) ->
      debugger
    # JPaymentCharge.charge options, -> debugger

  viewAppended:->
    tldList = []
    KD.remote.api.JDomain.getTldList (tlds)=>
      for tld in tlds
        tldList.push {title:".#{tld}", value: tld}
      @inputs.domains.setSelectOptions tldList
    @addSubView @domainListView

  setAvailableDomainsData:(domains)->
    @availableDomainsList.replaceAllItems domains
    @utils.defer => @domainListView.setClass 'in'