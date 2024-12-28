public with sharing class InvoiceCreatorController {
    // URL Parameters
    public String originRecord { get; set; }
    public String accountId { get; set; }
    public String invoiceDate { get; set; }
    public String invoiceDueDate { get; set; }
    public String childRelationshipName { get; set; }
    public String lineItemDescription { get; set; }
    public String lineItemQuantity { get; set; }
    public String lineItemUnitPrice { get; set; }

    // Properties to store queried records
    public Opportunity opportunityRecord { get; set; }
    public List<OpportunityLineItem> opportunityLineItems { get; set; }
    public Invoice__c newInvoice { get; set; }
    public List<Line_Item__c> newLineItems { get; set; }
    public String xeroJSON { get; set; }
    public Boolean showJSONSection { get; set; }

    // Constructor
    public InvoiceCreatorController() {
        showJSONSection = false;
        try {
            // Retrieve URL parameters
            Map<String, String> params = ApexPages.currentPage().getParameters();
            originRecord = params.get('origin_record');
            accountId = params.get('account');
            invoiceDate = params.get('invoice_date');
            invoiceDueDate = params.get('invoice_due_date');
            childRelationshipName = params.get('child_relationship_name');
            lineItemDescription = params.get('line_item_description');
            lineItemQuantity = params.get('line_item_quantity');
            lineItemUnitPrice = params.get('line_item_unit_price');

            // Query Opportunity and its Line Items if origin record exists
            if(String.isNotBlank(originRecord)) {
                queryOpportunityDetails();
            }
        } catch(Exception e) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Initialization Error: ' + e.getMessage()
            ));
        }
    }

    // Query Opportunity and its Line Items
    private void queryOpportunityDetails() {
        try {
            opportunityRecord = [
                SELECT Id, Name, AccountId, Account.Name, CloseDate,
                    (SELECT Id, Description, Quantity, UnitPrice, TotalPrice
                     FROM OpportunityLineItems
                     ORDER BY CreatedDate ASC)
                FROM Opportunity
                WHERE Id = :originRecord
                LIMIT 1
            ];

            opportunityLineItems = opportunityRecord.OpportunityLineItems;

            if(opportunityLineItems.isEmpty()) {
                ApexPages.addMessage(new ApexPages.Message(
                    ApexPages.Severity.WARNING,
                    'No line items found for this opportunity. Please add products to the opportunity before creating an invoice.'
                ));
            }
        } catch(Exception e) {
            throw new CustomException('Error querying Opportunity: ' + e.getMessage());
        }
    }

    // Show JSON for Xero API
    public void showJSON() {
        try {
            if(opportunityRecord != null) {
                xeroJSON = generateXeroJSON();
                showJSONSection = true;
            }
        } catch(Exception e) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Error generating JSON: ' + e.getMessage()
            ));
        }
    }

    // Generate JSON for Xero API
    private String generateXeroJSON() {
        Decimal total = 0;
        for(OpportunityLineItem oli : opportunityLineItems) {
            total += oli.Quantity * oli.UnitPrice;
        }

        Map<String, Object> xeroInvoice = new Map<String, Object>{
            'Type' => 'ACCREC',
            'Contact' => new Map<String, String>{
                'ContactID' => '0000000',
                'Name' => opportunityRecord.Account.Name
            },
            'Date' => opportunityRecord.CloseDate.format(),
            'DueDate' => opportunityRecord.CloseDate.format(),
            'Reference' => opportunityRecord.Name,
            'Status' => 'DRAFT',
            'Total' => total
        };

        List<Map<String, Object>> lineItems = new List<Map<String, Object>>();
        for(OpportunityLineItem oli : opportunityLineItems) {
            lineItems.add(new Map<String, Object>{
                'Description' => oli.Description,
                'Quantity' => oli.Quantity,
                'UnitAmount' => oli.UnitPrice,
                'LineAmount' => oli.Quantity * oli.UnitPrice,
                'AccountCode' => '4000',
                'TaxType' => 'OUTPUT'
            });
        }
        xeroInvoice.put('LineItems', lineItems);

        return JSON.serializePretty(xeroInvoice);
    }

    // Generate Invoice Number
    private String generateInvoiceNumber() {
        Long timestamp = DateTime.now().getTime();
        return 'INV-' + String.valueOf(timestamp).right(6);
    }

    // Create Invoice and Line Items
    public PageReference createInvoice() {
        Savepoint sp = Database.setSavepoint();

        try {
            // Validate we have line items
            if(opportunityLineItems == null || opportunityLineItems.isEmpty()) {
                throw new CustomException('No line items available to create invoice');
            }

            // Calculate total from opportunity line items
            Decimal total = 0;
            for(OpportunityLineItem oli : opportunityLineItems) {
                total += oli.Quantity * oli.UnitPrice;
            }

            // Create Invoice
            newInvoice = new Invoice__c(
                Account__c = determineAccountId(),
                Invoice_Date__c = determineDate(invoiceDate),
                Due_Date__c = determineDate(invoiceDueDate),
                Invoice_Reference__c = opportunityRecord.Name,
                Origin_Record__c = originRecord,
                Invoice_Number__c = generateInvoiceNumber(),
                Total__c = total
            );

            insert newInvoice;

            // Create Line Items
            newLineItems = new List<Line_Item__c>();
            for(OpportunityLineItem oli : opportunityLineItems) {
                Line_Item__c lineItem = new Line_Item__c(
                    Invoice__c = newInvoice.Id,
                    Description__c = oli.Description,
                    Quantity__c = oli.Quantity,
                    Unit_Price__c = oli.UnitPrice  // Amount will be calculated by formula field
                );
                newLineItems.add(lineItem);
            }

            insert newLineItems;

            // Redirect to the new invoice
            return new PageReference('/' + newInvoice.Id);

        } catch(Exception e) {
            Database.rollback(sp);
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Error creating invoice: ' + e.getMessage()
            ));
            return null;
        }
    }

    // Helper Methods
    private String determineAccountId() {
        if(String.isBlank(accountId) || accountId.equalsIgnoreCase('accountid')) {
            return opportunityRecord.AccountId;
        }
        return accountId;
    }

    private Date determineDate(String dateParam) {
        if(String.isBlank(dateParam) || dateParam.equalsIgnoreCase('closedate')) {
            return opportunityRecord.CloseDate;
        }
        return opportunityRecord.CloseDate;
    }

    // Custom Exception class
    public class CustomException extends Exception {}
}


