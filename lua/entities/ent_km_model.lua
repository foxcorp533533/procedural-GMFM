AddCSLuaFile()

ENT.Base = "base_anim"
ENT.Type = "anim"
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.AutomaticFrameAdvance = true

function ENT:Think()
	if SERVER then
		if not self.NoOwnerCheck and not IsValid(self:GetOwner()) then
			self:Remove()
			return
		end

		if IsValid(self:GetOwner()) then
			local owner = self:GetOwner()

			if self.maxKMTime ~= nil and owner.kmModel == self then
				if self.curKMTime == nil then
					self.curKMTime = 0
				else
					self.curKMTime = self.curKMTime + FrameTime()
				end

				if self.curKMTime > self.maxKMTime - 0.4 then
					local eyeAtt = self:LookupAttachment("eyes")
					local headBone = (eyeAtt and eyeAtt > 0) and self:GetAttachment(eyeAtt) or nil
					if headBone ~= nil then
						local eyeOffZ = owner.EyePos and (owner:GetPos().z - owner:EyePos().z) or -64
						owner:SetPos(Vector(headBone.Pos.x, headBone.Pos.y, headBone.Pos.z + eyeOffZ))
						if owner:IsPlayer() and owner.SetEyeAngles then
							owner:SetEyeAngles(Angle(headBone.Ang.x, headBone.Ang.y, 0))
						else
							owner:SetAngles(Angle(0, headBone.Ang.y, 0))
						end
					end
				end
			end
		end
	end

	if self.FrameAdvance then
		self:FrameAdvance()
	end
	self:NextThink(CurTime())
	return true
end

function ENT:RemoveDelay(delay)
	timer.Simple(delay, function()
		if not IsValid(self) then return end
		self:Remove()
	end)
end

function ENT:GetActiveWeapon()
	return self.Weapon
end

if SERVER then return end

function ENT:Draw() self:DrawModel() end
function ENT:DrawTranslucent() self:Draw() end
