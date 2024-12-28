public with sharing class InvoiceCreatorController {

    public String originRecord { get; set; }
    public String account { get; set; }
    public String invoiceDate { get; set; }
    public String invoiceDueDate { get; set; }
    public String childRelationshipName { get; set; }
    public String lineItemDescription { get; set; }
    public String lineItemQuantity { get; set; }
    public String lineItemUnitPrice { get; set; }

//comment

    public InvoiceCreatorController() {
        Map<String, String> params = ApexPages.currentPage().getParameters();
        originRecord = params.get('origin_record');
        account = params.get('account');
        invoiceDate = params.get('invoice_date');
        invoiceDueDate = params.get('invoice_due_date');
        childRelationshipName = params.get('child_relationship_name');
        lineItemDescription = params.get('line_item_description');
        lineItemQuantity = params.get('line_item_quantity');
        lineItemUnitPrice = params.get('line_item_unit_price');


    }
}


