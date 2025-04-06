using Microsoft.AspNetCore.Mvc;
using Snarf.DTO;
using Snarf.Infrastructure.Service;
using System.Security.Claims;

namespace Snarf.API.Controllers
{
    // Ajuste o nome da controller e a injeção de dependência conforme sua convenção
    public class PartyController : BaseController
    {
        private readonly IPartyService _partyService;

        public PartyController(IPartyService partyService)
        {
            _partyService = partyService;
        }

        [HttpPost("")]
        public async Task<IActionResult> Create([FromBody] PartyDTO partyCreateDTO)
        {
            // Pegamos o userId do token para associar ao Owner
            var whoIsCallingId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            partyCreateDTO.UserId = whoIsCallingId;

            var party = await _partyService.Create(partyCreateDTO);
            return StatusCode(party.Code, party);
        }

        [HttpPut("{id:guid}")]
        public async Task<IActionResult> UpdateParty([FromRoute] Guid id, [FromBody] PartyDTO updateDTO)
        {
            var party = await _partyService.Update(id, updateDTO);
            return StatusCode(party.Code, party);
        }

        /// <summary>
        /// Retorna todas as festas (exemplo: GET /Party/all{userId})
        /// Observação: no exemplo você sobrescreve userId com o do token.
        /// </summary>
        [HttpGet("all{userId:guid}")]
        public async Task<IActionResult> GetAllParties([FromRoute] Guid userId)
        {
            // No seu código, você chama de novo o token:
            userId = Guid.Parse(User.Claims.First(x => x.Type == ClaimTypes.NameIdentifier.ToString()).Value);

            var parties = await _partyService.GetAll(userId);
            return StatusCode(parties.Code, parties);
        }

        /// <summary>
        /// Lista de todos os participantes (Invited e Confirmed)
        /// Rota: GET /Party/{id}/all-users/{userId}
        /// </summary>
        [HttpGet("{id:guid}/all-users/{userId:guid}")]
        public async Task<IActionResult> GetAllParticipants([FromRoute] Guid id, [FromRoute] Guid userId)
        {
            // Você sobrescreve aqui de novo, mas pode ficar se a regra é usar só o do token.
            userId = Guid.Parse(User.Claims.First(x => x.Type == ClaimTypes.NameIdentifier.ToString()).Value);

            var parties = await _partyService.GetAllParticipants(id, userId);
            return StatusCode(parties.Code, parties);
        }

        /// <summary>
        /// Detalhes de uma festa específica para um usuário,
        /// Rota: GET /Party/{id}/details/{userId}
        /// </summary>
        [HttpGet("{id:guid}/details/{userId:guid}")]
        public async Task<IActionResult> GetPartyDetails([FromRoute] Guid id, [FromRoute] Guid userId)
        {
            userId = Guid.Parse(User.Claims.First(x => x.Type == ClaimTypes.NameIdentifier.ToString()).Value);
            var party = await _partyService.GetById(id, userId);
            return StatusCode(party.Code, party);
        }

        /// <summary>
        /// Deleta a festa (somente o dono).
        /// Rota: DELETE /Party/{id}/delete/{userId}
        /// </summary>
        [HttpDelete("{id:guid}/delete/{userId:guid}")]
        public async Task<IActionResult> Delete([FromRoute] Guid id, [FromRoute] Guid userId)
        {
            userId = Guid.Parse(User.Claims.First(x => x.Type == ClaimTypes.NameIdentifier.ToString()).Value);
            var party = await _partyService.Delete(id, userId);
            return StatusCode(party.Code, party);
        }

        // Rota para o host convidar explicitamente (fluxo 1)
        [HttpPut("{id:guid}/invite-users")]
        public async Task<IActionResult> InviteUsersToParty([FromRoute] Guid id, [FromBody] List<string> userIds)
        {
            // O user que está chamando esse endpoint (possivelmente o host)
            var whoIsCallingId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            var result = await _partyService.InviteUsers(id, userIds, whoIsCallingId);
            return StatusCode(result.Code, result);
        }

        // Rota para o usuário solicitar participação (fluxo 2)
        [HttpPut("{id:guid}/request-participation")]
        public async Task<IActionResult> RequestParticipation([FromRoute] Guid id)
        {
            // O user que está chamando (solicitando)
            var whoIsCallingId = User.FindFirstValue(ClaimTypes.NameIdentifier);

            var result = await _partyService.RequestParticipation(id, whoIsCallingId);
            return StatusCode(result.Code, result);
        }

        // Confirmar participação (pode ser o host confirmando um solicitante,
        // ou um convidado se auto-confirmando - mas só se for convidado
        // explicitamente pelo host)
        [HttpPost("{id:guid}/confirm/{targetUserId:guid}")]
        public async Task<IActionResult> ConfirmParty([FromRoute] Guid id, [FromRoute] Guid targetUserId)
        {
            var whoIsCallingId = User.FindFirstValue(ClaimTypes.NameIdentifier);

            var result = await _partyService.ConfirmUser(id, whoIsCallingId, targetUserId.ToString());
            return StatusCode(result.Code, result);
        }

        // Recusar participação (host recusa solicitante ou convidado; 
        // convidado também pode se recusar)
        [HttpPost("{id:guid}/decline/{targetUserId:guid}")]
        public async Task<IActionResult> DeclineUser([FromRoute] Guid id, [FromRoute] Guid targetUserId)
        {
            var whoIsCallingId = User.FindFirstValue(ClaimTypes.NameIdentifier);

            var result = await _partyService.DeclineUser(id, whoIsCallingId, targetUserId.ToString());
            return StatusCode(result.Code, result);
        }
    }
}