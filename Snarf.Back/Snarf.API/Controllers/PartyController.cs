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
            partyCreateDTO.UserId = User.Claims.First(x => x.Type == ClaimTypes.NameIdentifier.ToString()).Value;
            var party = await partyService.Create(partyCreateDTO);
            return StatusCode(party.Code, party);
        }

        [HttpPut("{id:guid}")]
        public async Task<IActionResult> UpdateParty([FromRoute] Guid id, [FromBody] PartyDTO updateDTO)
        {
            var party = await partyService.Update(id, updateDTO);
            return StatusCode(party.Code, party);
        }

        [HttpPut("{id:guid}/invite-users")]
        public async Task<IActionResult> InviteUsersToParty([FromRoute] Guid id, [FromBody] List<string> request)
        {
            var party = await partyService.InviteUsers(id, request);
            return StatusCode(party.Code, party);
        }

        [HttpPut("{id:guid}/confirm-user/{userId:guid}")]
        public async Task<IActionResult> ConfirmParty([FromRoute] Guid id, [FromRoute] Guid userId)
        {
            userId = Guid.Parse(User.Claims.First(x => x.Type == ClaimTypes.NameIdentifier.ToString()).Value);
            var party = await partyService.ConfirmUser(id, userId);
            return StatusCode(party.Code, party);
        }

        [HttpPut("{id:guid}/decline-user/{userId:guid}")]
        public async Task<IActionResult> DeclineUser([FromRoute] Guid id, [FromRoute] Guid userId)
        {
            userId = Guid.Parse(User.Claims.First(x => x.Type == ClaimTypes.NameIdentifier.ToString()).Value);
            var party = await partyService.DeclineUser(id, userId);
            return StatusCode(party.Code, party);
        }

        [HttpGet("all{userId:guid}")]
        public async Task<IActionResult> GetAllParties([FromRoute] Guid userId)
        {
            userId = Guid.Parse(User.Claims.First(x => x.Type == ClaimTypes.NameIdentifier.ToString()).Value);
            var parties = await partyService.GetAll(userId);
            return StatusCode(parties.Code, parties);
        }

        [HttpGet("{id:guid}/all-users/{userId:guid}")]
        public async Task<IActionResult> GetAllParticipants([FromRoute] Guid id, [FromRoute] Guid userId)
        {
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
    }
}