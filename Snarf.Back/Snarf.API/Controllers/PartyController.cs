using Microsoft.AspNetCore.Mvc;
using Snarf.DTO;
using Snarf.Infrastructure.Service;
using System.Security.Claims;

namespace Snarf.API.Controllers
{
    public class PartyController(IPartyService partyService) : BaseController
    {
        [HttpPost("")]
        public async Task<IActionResult> Create([FromBody] PartyDTO partyCreateDTO)
        {
            var whoIsCallingId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            partyCreateDTO.UserId = whoIsCallingId;

            var party = await partyService.Create(partyCreateDTO);
            return StatusCode(party.Code, party);
        }

        [HttpPut("{id:guid}")]
        public async Task<IActionResult> UpdateParty([FromRoute] Guid id, [FromBody] PartyDTO updateDTO)
        {
            var party = await partyService.Update(id, updateDTO);
            return StatusCode(party.Code, party);
        }

        [HttpGet("all{userId:guid}")]
        public async Task<IActionResult> GetAllParties([FromRoute] Guid userId)
        {
            // No seu código, você chama de novo o token:
            userId = Guid.Parse(User.Claims.First(x => x.Type == ClaimTypes.NameIdentifier.ToString()).Value);

            var parties = await partyService.GetAll(userId);
            return StatusCode(parties.Code, parties);
        }

        [HttpGet("{id:guid}/all-users/{userId:guid}")]
        public async Task<IActionResult> GetAllParticipants([FromRoute] Guid id, [FromRoute] Guid userId)
        {
            // Você sobrescreve aqui de novo, mas pode ficar se a regra é usar só o do token.
            userId = Guid.Parse(User.Claims.First(x => x.Type == ClaimTypes.NameIdentifier.ToString()).Value);

            var parties = await partyService.GetAllParticipants(id, userId);
            return StatusCode(parties.Code, parties);
        }

        [HttpGet("{id:guid}/details/{userId:guid}")]
        public async Task<IActionResult> GetPartyDetails([FromRoute] Guid id, [FromRoute] Guid userId)
        {
            userId = Guid.Parse(User.Claims.First(x => x.Type == ClaimTypes.NameIdentifier.ToString()).Value);
            var party = await partyService.GetById(id, userId);
            return StatusCode(party.Code, party);
        }

        [HttpDelete("{id:guid}/delete/{userId:guid}")]
        public async Task<IActionResult> Delete([FromRoute] Guid id, [FromRoute] Guid userId)
        {
            userId = Guid.Parse(User.Claims.First(x => x.Type == ClaimTypes.NameIdentifier.ToString()).Value);
            var party = await partyService.Delete(id, userId);
            return StatusCode(party.Code, party);
        }

        [HttpPut("{id:guid}/invite-users")]
        public async Task<IActionResult> InviteUsersToParty([FromRoute] Guid id, [FromBody] List<string> userIds)
        {
            var whoIsCallingId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            var result = await partyService.InviteUsers(id, userIds, whoIsCallingId);
            return StatusCode(result.Code, result);
        }

        [HttpPut("{id:guid}/request-participation")]
        public async Task<IActionResult> RequestParticipation([FromRoute] Guid id)
        {
            var whoIsCallingId = User.FindFirstValue(ClaimTypes.NameIdentifier);

            var result = await partyService.RequestParticipation(id, whoIsCallingId);
            return StatusCode(result.Code, result);
        }

        [HttpPost("{id:guid}/confirm/{targetUserId:guid}")]
        public async Task<IActionResult> ConfirmParty([FromRoute] Guid id, [FromRoute] Guid targetUserId)
        {
            var whoIsCallingId = User.FindFirstValue(ClaimTypes.NameIdentifier);

            var result = await partyService.ConfirmUser(id, whoIsCallingId, targetUserId.ToString());
            return StatusCode(result.Code, result);
        }

        [HttpPost("{id:guid}/decline/{targetUserId:guid}")]
        public async Task<IActionResult> DeclineUser([FromRoute] Guid id, [FromRoute] Guid targetUserId)
        {
            var whoIsCallingId = User.FindFirstValue(ClaimTypes.NameIdentifier);

            var result = await partyService.DeclineUser(id, whoIsCallingId, targetUserId.ToString());
            return StatusCode(result.Code, result);
        }
    }
}