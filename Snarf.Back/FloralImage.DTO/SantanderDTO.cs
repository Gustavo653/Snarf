using System.Text.Json.Serialization;

namespace FloralImage.DTO
{
    public class OAuthResponse
    {
        [JsonPropertyName("access_token")]
        public string? AccessToken { get; set; }

        [JsonPropertyName("expires_in")]
        public int ExpiresIn { get; set; }
    }

    public class WorkspacesResponse
    {
        [JsonPropertyName("content")]
        public List<Workspace>? Content { get; set; }
    }

    public class Workspace
    {
        [JsonPropertyName("id")]
        public string? Id { get; set; }

        [JsonPropertyName("status")]
        public string? Status { get; set; }

        [JsonPropertyName("type")]
        public string? Type { get; set; }

        [JsonPropertyName("description")]
        public string? Description { get; set; }

        [JsonPropertyName("covenants")]
        public List<Covenant>? Covenants { get; set; }
    }

    public class Covenant
    {
        [JsonPropertyName("code")]
        public string? Code { get; set; }
    }


    public class BankSlip
    {
        public string nsuCode { get; set; }
        public string nsuDate { get; set; }
        public string environment { get; set; }
        public string covenantCode { get; set; }
        public Payer payer { get; set; }
        public Beneficiary beneficiary { get; set; }
        public object[] sharing { get; set; }
        public string bankNumber { get; set; }
        public string clientNumber { get; set; }
        public string dueDate { get; set; }
        public string issueDate { get; set; }
        public string documentKind { get; set; }
        public string nominalValue { get; set; }
        public string finePercentage { get; set; }
        public string fineQuantityDays { get; set; }
        public string interestPercentage { get; set; }
        public Discount discount { get; set; }
        public string deductionValue { get; set; }
        public string protestType { get; set; }
        public string protestQuantityDays { get; set; }
        public string writeOffQuantityDays { get; set; }
        public string paymentType { get; set; }
        public string parcelsQuantity { get; set; }
        public string valueType { get; set; }
        public string minValueOrPercentage { get; set; }
        public string maxValueOrPercentage { get; set; }
        public string iofPercentage { get; set; }
        public string txId { get; set; }
        public string participantCode { get; set; }
        public string[] messages { get; set; }
        public string barcode { get; set; }
        public string digitableLine { get; set; }
        public string entryDate { get; set; }
        public string qrCodePix { get; set; }
        public string qrCodeUrl { get; set; }
    }

    public class Payer
    {
        public string documentType { get; set; }
        public string documentNumber { get; set; }
        public string name { get; set; }
        public string address { get; set; }
        public string neighborhood { get; set; }
        public string city { get; set; }
        public string state { get; set; }
        public string zipCode { get; set; }
    }

    public class Beneficiary
    {
        public string name { get; set; }
        public string documentType { get; set; }
        public string documentNumber { get; set; }
    }

    public class Discount
    {
        public string type { get; set; }
        public Discountone discountOne { get; set; }
        public Discounttwo discountTwo { get; set; }
        public Discountthree discountThree { get; set; }
    }

    public class Discountone
    {
        public string value { get; set; }
        public string limitDate { get; set; }
    }

    public class Discounttwo
    {
        public string value { get; set; }
        public string limitDate { get; set; }
    }

    public class Discountthree
    {
        public string value { get; set; }
        public string limitDate { get; set; }
    }

    public class BankSlipQueryResponse
    {
        public string returnCode { get; set; }
        public string documentNumber { get; set; }
        public int beneficiaryCode { get; set; }
        public int bankNumber { get; set; }
        public string clientNumber { get; set; }
        public string dueDate { get; set; }
        public float nominalValue { get; set; }
        public string issueDate { get; set; }
        public string participantCode { get; set; }
        public string status { get; set; }
        public Bankslipdata bankSlipData { get; set; }
        public Payerdata payerData { get; set; }
        public Guarantordata guarantorData { get; set; }
        public string[] messageData { get; set; }
    }

    public class Bankslipdata
    {
        public int portfolio { get; set; }
        public int modality { get; set; }
        public int branch { get; set; }
        public int accountNumber { get; set; }
        public string processingDate { get; set; }
        public string entryDate { get; set; }
        public string protestDescription { get; set; }
        public int protestQuantityDays { get; set; }
        public string writeOffIndicativeDescription { get; set; }
        public int writeOffQuantityDays { get; set; }
        public string documentKind { get; set; }
        public string currency { get; set; }
        public string currencyQuantity { get; set; }
        public string ddaPayerIndicative { get; set; }
        public string warranty { get; set; }
        public string paymentType { get; set; }
        public string valueOrPercentageIndicative { get; set; }
        public float minValueOrPercentage { get; set; }
        public float maxValueOrPercentage { get; set; }
        public int parcelsQuantity { get; set; }
        public int paidParcelsQuantity { get; set; }
        public float amountReceived { get; set; }
        public float interestPercentage { get; set; }
        public float iofPercentage { get; set; }
        public string digitableLine { get; set; }
        public string barCode { get; set; }
    }

    public class Payerdata
    {
        public int payerDocumentType { get; set; }
        public string payerDocumentNumber { get; set; }
        public string payerName { get; set; }
        public string payerAddress { get; set; }
        public string payerNeighborhood { get; set; }
        public string payerZipCode { get; set; }
        public string payerCounty { get; set; }
        public string payerStateAbbreviation { get; set; }
        public string payerEmail { get; set; }
    }

    public class Guarantordata
    {
        public int guarantorDocumentType { get; set; }
        public string guarantorDocumentNumber { get; set; }
        public string guarantorName { get; set; }
    }

    public class BankSlipPDFResponse
    {
        public string link { get; set; }
    }
}
