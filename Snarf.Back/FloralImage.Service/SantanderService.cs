using FloralImage.Domain.Enum;
using FloralImage.DTO;
using FloralImage.Infrastructure.Repository;
using FloralImage.Infrastructure.Service;
using Microsoft.EntityFrameworkCore;
using Serilog;
using System.Globalization;
using System.Net.Http.Headers;
using System.Security.Cryptography.X509Certificates;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace FloralImage.Service
{
    public class SantanderService : ISantanderService
    {
        private const int CovenantCode = 582789;
        private readonly IInvoiceRepository _invoiceRepository;
        private readonly IInvoiceConfigurationRepository _invoiceConfigurationRepository;
        private readonly string _urlApi;
        private readonly string _clientId;
        private readonly string _clientSecret;
        private readonly string _certificateBase64;
        private readonly string _certificatePassword;

        private static string? _cachedToken;
        private static DateTime _tokenExpiration = DateTime.MinValue;

        private readonly X509Certificate2 _certificate;
        private readonly HttpClient _httpClient;

        public SantanderService(IInvoiceRepository invoiceRepository, IInvoiceConfigurationRepository invoiceConfigurationRepository)
        {
            _invoiceRepository = invoiceRepository;
            _invoiceConfigurationRepository = invoiceConfigurationRepository;
            _urlApi = Environment.GetEnvironmentVariable("SantanderUrl")!;
            _clientId = Environment.GetEnvironmentVariable("SantanderClientId")!;
            _clientSecret = Environment.GetEnvironmentVariable("SantanderClientSecret")!;
            _certificateBase64 = Environment.GetEnvironmentVariable("SantanderCertificatePFXBase64")!;
            _certificatePassword = Environment.GetEnvironmentVariable("SantanderCertificatePassword")!;

            if (string.IsNullOrEmpty(_urlApi) ||
                string.IsNullOrEmpty(_clientId) ||
                string.IsNullOrEmpty(_clientSecret) ||
                string.IsNullOrEmpty(_certificateBase64) ||
                string.IsNullOrEmpty(_certificatePassword))
            {
                throw new ApplicationException("As variáveis de ambiente necessárias não foram definidas.");
            }

            _certificate = LoadCertificate();
            _httpClient = CreateHttpClient();
        }

        private X509Certificate2 LoadCertificate()
        {
            Log.Information("Inicializando certificado");
            byte[] certificateBytes = Convert.FromBase64String(_certificateBase64);
            return new X509Certificate2(certificateBytes, _certificatePassword);
        }

        private HttpClient CreateHttpClient()
        {
            var handler = new HttpClientHandler();
            handler.ClientCertificates.Add(_certificate);

            var client = new HttpClient(handler);
            return client;
        }

        private async Task<T> ProcessResponse<T>(HttpResponseMessage response)
        {
            var responseBody = await response.Content.ReadAsStringAsync();
            if (!response.IsSuccessStatusCode)
            {
                throw new ApplicationException($"Erro na requisição: {response.StatusCode} - {responseBody}");
            }

            Log.Information($"Body recebido: {responseBody}");
            return JsonSerializer.Deserialize<T>(responseBody) ?? throw new ApplicationException("Resposta inválida ou nula.");
        }

        private async Task<HttpResponseMessage> SendRequest(HttpMethod method, string url, HttpContent? content = null, string? token = null)
        {
            var request = new HttpRequestMessage(method, url);
            Log.Information($"Enviando requisição para URL: {method} - {url}");

            if (content != null)
            {
                Log.Information($"Body enviado: {await content.ReadAsStringAsync()}");
                request.Content = content;
            }

            if (!string.IsNullOrEmpty(token))
            {
                request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
                request.Headers.Add("X-Application-Key", _clientId);
            }

            return await _httpClient.SendAsync(request);
        }

        private async Task<string> GetToken()
        {
            if (_cachedToken != null && _tokenExpiration > DateTime.UtcNow)
            {
                Log.Information("Retornando token cacheado");
                return _cachedToken;
            }

            try
            {
                Log.Information("Solicitando novo token");
                var content = new FormUrlEncodedContent(new[]
                {
                    new KeyValuePair<string, string>("client_id", _clientId),
                    new KeyValuePair<string, string>("client_secret", _clientSecret),
                    new KeyValuePair<string, string>("grant_type", "client_credentials")
                });

                var response = await SendRequest(HttpMethod.Post, $"{_urlApi}/auth/oauth/v2/token", content);
                var jsonResponse = await ProcessResponse<OAuthResponse>(response);

                _cachedToken = jsonResponse.AccessToken;
                _tokenExpiration = DateTime.UtcNow.AddSeconds(jsonResponse.ExpiresIn);

                return _cachedToken;
            }
            catch (Exception ex)
            {
                Log.Error($"Erro ao obter o token: {ex.Message}", ex);
                throw;
            }
        }

        private async Task<Workspace> GetWorkspace()
        {
            try
            {
                var token = await GetToken();

                Log.Information("Solicitando workspaces ativos do tipo BILLING");
                var response = await SendRequest(HttpMethod.Get, $"{_urlApi}/collection_bill_management/v2/workspaces", token: token);

                var workspaces = await ProcessResponse<WorkspacesResponse>(response);

                var workspace = workspaces.Content?.FirstOrDefault(w => w.Status == "ACTIVE" && w.Type == "BILLING" && w.Covenants.FirstOrDefault().Code == CovenantCode.ToString());

                if (workspace == null)
                {
                    return await CreateWorkspace();
                }

                return workspace;
            }
            catch (Exception ex)
            {
                Log.Error($"Erro ao obter o primeiro ID ativo do tipo BILLING: {ex.Message}", ex);
                throw;
            }
        }

        private async Task<Workspace> CreateWorkspace()
        {
            try
            {
                var token = await GetToken();

                Log.Information("Criando um novo workspace do tipo BILLING");

                var body = new
                {
                    type = "BILLING",
                    covenants = new[]
                    {
                        new { code = CovenantCode }
                    },
                    description = "Workspace Padrão",
                    //bankSlipBillingWebhookActive = false,
                    //pixBillingWebhookActive = false,
                    //webhookURL = ""
                };

                var jsonContent = new StringContent(
                    JsonSerializer.Serialize(body),
                    System.Text.Encoding.UTF8,
                    "application/json"
                );

                var response = await SendRequest(HttpMethod.Post, $"{_urlApi}/collection_bill_management/v2/workspaces", jsonContent, token);
                var createdWorkspace = await ProcessResponse<Workspace>(response);

                Log.Information($"Workspace criado com sucesso: ID {createdWorkspace.Id}");

                return createdWorkspace;
            }
            catch (Exception ex)
            {
                Log.Error($"Erro ao criar o workspace do tipo BILLING: {ex.Message}", ex);
                throw;
            }
        }

        public async Task<string?> CreateBankSlip(Guid invoiceId)
        {
            try
            {
                var invoiceConfiguration = await _invoiceConfigurationRepository.GetEntities().FirstOrDefaultAsync() ?? throw new Exception("Configuração de fatura não encontrada");
                var invoice = await _invoiceRepository.GetTrackedEntities()
                                                      .Include(x => x.Customer).ThenInclude(x => x.State)
                                                      .Include(x => x.Customer).ThenInclude(x => x.City)
                                                      .Include(x => x.InvoiceItems)
                                                      .FirstOrDefaultAsync(x => x.Id == invoiceId) ?? throw new Exception($"A fatura com id {invoiceId} não foi encontrada");

                if (invoice.Customer.InvoiceGenerationOption == InvoiceGenerationOption.InvoiceOnly)
                {
                    invoice.InvoiceStatus = InvoiceStatus.Billed;
                    await _invoiceRepository.SaveChangesAsync();
                    return null;
                }

                var token = await GetToken();

                var workspace = await GetWorkspace();

                Log.Information($"Criando boleto para fatura {invoiceId}");

                var body = new BankSlip
                {
                    environment = _urlApi.Contains("https://trust-open.api.santander.com.br") ? "PRODUCAO" : "TESTE",
                    nsuCode = invoice.Number.ToString(),
                    nsuDate = invoice.IssueDate.ToString("yyyy-MM-dd"),
                    covenantCode = CovenantCode.ToString(),
                    bankNumber = invoice.Number.ToString(),
                    clientNumber = invoice.Number.ToString(),
                    finePercentage = "5.00",
                    fineQuantityDays = "7",
                    dueDate = invoice.BillDueDate.Value.ToString("yyyy-MM-dd"),
                    issueDate = invoice.IssueDate.ToString("yyyy-MM-dd"),
                    nominalValue = invoice.InvoiceItems.Sum(x => x.Quantity * x.Price).ToString("F2", CultureInfo.InvariantCulture),
                    payer = new Payer
                    {
                        name = SafeSubstring(Regex.Replace(invoice.Customer.CompanyName, @"[^a-zA-Z0-9&\s]", ""), 0, 40),
                        documentType = invoice.Customer.Document.Length <= 14 ? "CPF" : "CNPJ",
                        documentNumber = Regex.Replace(invoice.Customer.Document, @"\D", ""),
                        address = SafeSubstring(Regex.Replace(invoice.Customer.Address, @"[^a-zA-Z0-9\s]", ""), 0, 40),
                        neighborhood = invoice.Customer.City.Name,
                        city = invoice.Customer.City.Name,
                        state = invoice.Customer.State.Abbreviation,
                        zipCode = invoice.Customer.PostalCode
                    },
                    beneficiary = new Beneficiary
                    {
                        name = Regex.Replace(invoiceConfiguration.CompanyName, @"[^a-zA-Z0-9&\s]", ""),
                        documentType = "CNPJ",
                        documentNumber = Regex.Replace(invoiceConfiguration.Document, @"\D", "")
                    },
                    documentKind = "DUPLICATA_SERVICO",
                    paymentType = "REGISTRO",
                    messages =
                    [
                        $"Boleto referente a fatura {invoice.Number}"
                    ]
                };

                var jsonContent = new StringContent(
                    JsonSerializer.Serialize(body),
                    System.Text.Encoding.UTF8,
                    "application/json"
                );

                var response = await SendRequest(HttpMethod.Post, $"{_urlApi}/collection_bill_management/v2/workspaces/{workspace.Id}/bank_slips", jsonContent, token);
                var bankSlip = await ProcessResponse<BankSlip>(response);

                Log.Information($"Boleto criado para fatura {invoiceId} com Codigo de barras: {bankSlip.barcode}");

                invoice.InvoiceStatus = InvoiceStatus.Billed;
                await _invoiceRepository.SaveChangesAsync();

                return bankSlip.barcode;
            }
            catch (Exception ex)
            {
                Log.Error($"Erro ao criar o boleto para fatura: {invoiceId}", ex);
                throw;
            }
        }

        public async Task<string?> CancelBankSlip(Guid invoiceId)
        {
            try
            {
                var invoice = await _invoiceRepository.GetEntities()
                                                      .Include(x => x.Customer)
                                                      .FirstOrDefaultAsync(x => x.Id == invoiceId) ?? throw new Exception($"A fatura com id {invoiceId} não foi encontrada");

                if (invoice.Customer.InvoiceGenerationOption == InvoiceGenerationOption.InvoiceOnly)
                    return null;

                var token = await GetToken();

                var workspace = await GetWorkspace();

                Log.Information($"Cancelando boleto para fatura {invoiceId}");

                var body = new
                {
                    covenantCode = CovenantCode,
                    bankNumber = invoice.Number,
                    operation = "BAIXAR"
                };

                var jsonContent = new StringContent(
                    JsonSerializer.Serialize(body),
                    System.Text.Encoding.UTF8,
                    "application/json"
                );

                var response = await SendRequest(HttpMethod.Patch, $"{_urlApi}/collection_bill_management/v2/workspaces/{workspace.Id}/bank_slips", jsonContent, token);
                var bankSlip = await ProcessResponse<BankSlip>(response);

                Log.Information($"Boleto cancelado para fatura {invoiceId}");

                return bankSlip.barcode;
            }
            catch (Exception ex)
            {
                Log.Error($"Erro ao criar o boleto para fatura: {invoiceId}", ex);
                throw;
            }
        }

        public async Task<byte[]> GetPDFBankSlip(Guid invoiceId)
        {
            try
            {
                var invoice = await _invoiceRepository
                    .GetEntities()
                    .Include(x => x.Customer)
                    .FirstOrDefaultAsync(x => x.Id == invoiceId)
                    ?? throw new Exception($"A fatura com id {invoiceId} não foi encontrada");

                var token = await GetToken();

                Log.Information($"Obtendo PDF para boleto da fatura {invoiceId}");

                var body = new
                {
                    payerDocumentNumber = Convert.ToInt64(Regex.Replace(invoice.Customer.Document, @"\D", ""))
                };

                var jsonContent = new StringContent(
                    JsonSerializer.Serialize(body),
                    System.Text.Encoding.UTF8,
                    "application/json"
                );

                var response = await SendRequest(
                    HttpMethod.Post,
                    $"{_urlApi}/collection_bill_management/v2/bills/{invoice.Number}.{CovenantCode}/bank_slips",
                    jsonContent,
                    token
                );

                var urlResponse = await ProcessResponse<BankSlipPDFResponse>(response);

                Log.Information($"Link do boleto: {urlResponse.link}");

                using var httpClient = new HttpClient();
                var pdfBytes = await httpClient.GetByteArrayAsync(urlResponse.link);

                Log.Information($"PDF do boleto para a fatura {invoiceId} foi baixado com sucesso.");

                return pdfBytes;
            }
            catch (Exception ex)
            {
                Log.Error($"Erro ao criar o boleto para fatura: {invoiceId}", ex);
                throw;
            }
        }

        public async Task CheckStatusBankSlip(Guid invoiceId)
        {
            try
            {
                var invoice = await _invoiceRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Id == invoiceId) ?? throw new Exception($"A fatura com id {invoiceId} não foi encontrada");

                var token = await GetToken();

                Log.Information($"Buscando status do boleto para fatura {invoiceId}");

                var response = await SendRequest(HttpMethod.Get, $"{_urlApi}/collection_bill_management/v2/bills/{CovenantCode}.{invoice.Number}?tipoConsulta=bankslip", null, token);
                var bankSlip = await ProcessResponse<BankSlipQueryResponse>(response);

                Log.Information($"Boleto com status {bankSlip.status} para fatura {invoiceId}");
                switch (bankSlip.status)
                {
                    case "LIQUIDADO":
                        invoice.InvoiceStatus = InvoiceStatus.Paid;
                        break;
                    case "BAIXADO":
                        invoice.InvoiceStatus = InvoiceStatus.Cancelled;
                        break;
                }
                await _invoiceRepository.SaveChangesAsync();
            }
            catch (Exception ex)
            {
                Log.Error($"Erro ao buscar status do boleto para fatura: {invoiceId}", ex);
                throw;
            }
        }

        private string SafeSubstring(string input, int startIndex, int length)
        {
            if (string.IsNullOrEmpty(input))
                return string.Empty;

            if (startIndex >= input.Length)
                return string.Empty;

            if (startIndex + length > input.Length)
                length = input.Length - startIndex;

            return input.Substring(startIndex, length);
        }
    }
}
