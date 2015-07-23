//How many to create?
var count = 10000;

var memberType = ApplicationContext.Services.MemberTypeService.GetAll()
	.OrderBy(x => x.Name)
	.First(x => x.Name.StartsWith("_") == false);

("Creating with member type: " + memberType.Name).Dump();

for(var i = 0;i< count;i++)
{
    var id = "BM_" + i + Guid.NewGuid().ToString("N");
    var member = ApplicationContext.Services.MemberService.CreateMemberWithIdentity(id, id + "@bm.com", id, memberType);
	("Created member: " + id).Dump();
}

"Done".Dump();