function EFFECT:Init( data )

    local Pos = data:GetOrigin()
	local Norm = data:GetNormal()
	local vOffset = data:GetOrigin()
	local emitter = ParticleEmitter( vOffset )
	for i = 1,math.random(1,1) do 	
		local particle = emitter:Add( "effects/flour", Pos + Norm * 3 )
		particle:SetDieTime( 0.5 )
		particle:SetStartAlpha( 255 )
		particle:SetEndAlpha( 0 )
		particle:SetStartSize( 5 )
		particle:SetEndSize( 10 )
		particle:SetColor( 0, 0, 0 )
		particle:SetCollide(true)
		particle:SetBounce(0.45)
	end

	emitter:Finish()
end

function EFFECT:Think()
	return false
end


function EFFECT:Render()
end