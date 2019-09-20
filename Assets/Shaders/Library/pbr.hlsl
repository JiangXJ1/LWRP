

float SchlickFresnel(float u)
{
	float m = clamp(1 - u, 0, 1);
	float m2 = m * m;
	return m2 * m2*m; // pow(m,5)
}

half Pow5(half v)
{
	return v * v * v * v * v;
}

// Diffuse项
float3 Diffuse_Burley_Disney(float3 DiffuseColor, float Roughness, float NdotV, float NdotL, float VdotH)
{
	float FD90 = 0.5 + 2 * VdotH * VdotH * Roughness;
	float FdV = 1 + (FD90 - 1) * Pow5(1 - NdotV);
	float FdL = 1 + (FD90 - 1) * Pow5(1 - NdotL);
	return DiffuseColor * ((1 / PI) * FdV * FdL);
}

//-------------------D Start---------------------
//法线分布函数 Specular D 各向同性
float D_GTR(float alpha, float NdotH)
{
	float a2 = alpha * alpha;
	float cos2th = NdotH * NdotH;
	float den = (1.0 + (a2 - 1.0) * cos2th);

	return a2 / (PI * den * den);
}

//法线分布函数 Specular D 各向异性
//HdotT dot(half,tangent) hdotb dot(half,bittangent) at alpha of tangent  ab alpha of bittangent
float D_GTR_aniso(float HdotT, float HdotB, float NdotH, float at, float ab)
{
	float deno = HdotT * HdotT / (at * at) + HdotB * HdotB / (ab * ab) + NdotH * NdotH;
	return 1.0 / (PI * at * ab * deno * deno);
}

//-----------------------D End----------------------

//------------------------G Start------------------------
//GGX G项，各项同性版本
float GGX_G(float dotVN, float alphag)
{
	float a = alphag * alphag;
	float b = dotVN * dotVN;
	return 1.0 / (dotVN + sqrt(a + b - a * b));
}

//GGX G项，各项异性版本
float GGX_G_aniso(float dotVN, float dotVX, float dotVY, float at, float ab)
{
	return 1.0 / (dotVN + sqrt(pow(dotVX * at, 2.0) + pow(dotVY * ab, 2.0) + pow(dotVN, 2.0)));
}
//------------------------G End------------------------
