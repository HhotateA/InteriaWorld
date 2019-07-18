Shader "Custom/InteriorMappingTest" 
{
	Properties 
	{
		_RoomScale ("RoomScale",vector) = (1,1,1,1)
		_Offset ("Offset", Vector) = (0, 0, 0, 0.0)
		_OffsetVec ("OffsetVec", Vector) = (0, 0, 0, 0.0)
		_MainTex("Main Texture", 2D) = "white"{}
		[HDR]_Color ("color",color) = (1,1,1,1)
		_FloorTex("Floor Texture", 2D) = "white"{}
		_CeilTex("Ceil Texture", 2D) = "white"{}
		_RightTex("Right Texture", 2D) = "white"{}
		_LeftTex("Left Texture", 2D) = "white"{}
		_FrontTex("Front Texture", 2D) = "white"{}
		_BackTex("Back Texture", 2D) = "white"{}
		_Tiles ("_Tiles", Float) = 0.25
		_DistanceBetweenWalls ("_Tiles", Float) = 0.25
		_ZPlusVal ("ZPlusVal",range(0,1)) = 0.0001
	}
	
	SubShader 
	{
		Tags
		{
			//"RenderType"="Opaque"
			"Queue"="Transparent"
		}
		Cull off
		//ZWrite off
		//Blend SrcAlpha OneMinusSrcAlpha
		
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"
			#define INTERSECT_INF 2147483647

			float4 _Offset,_OffsetVec;
			sampler2D _MainTex;
			float4 _Color;
			sampler2D _FloorTex, _CeilTex, _FrontTex, _BackTex, _RightTex, _LeftTex;
			float4 _FloorTex_ST, _CeilTex_ST, _FrontTex_ST, _BackTex_ST, _RightTex_ST, _LeftTex_ST;
			float4 _RoomScale;
			float _Tiles;
			float _ZPlusVal;
			float _DistanceBetweenWalls;

			struct v2f
			{
				float4 pos : SV_POSITION;
				float3 normal : NORMAL;
				float3 viewPos : VIEW_POS;
				float3 objectViewDir : VIEW_DIR;
				float3 objectPos : OBJ_POS;
				float2 uv : TEXCOORD0;
			};

			//---------------------------------------------------
			float rand(float3 co)
			{
				return frac(sin(dot(co.xyz, float3(12.9898, 78.233, 56.787))) * 43758.5453);
			}

			float3 GetRandomTiledUV(float3 uvw, float between, float tile)
			{
				float r = rand(floor((uvw + _ZPlusVal) / between)); // 微妙に内側に入れることでZファイティングを防ぐ
				r = floor(r * 10000) % tile;
					
				uvw.xy = frac(uvw.xy / between);
				uvw.x += floor(r / (tile / 2));
				uvw.y += floor(r % (tile / 2));
				uvw.xy = uvw.xy / (tile / 2);
				uvw.z = r;
					
				return uvw;
			}

			float4 GetCeilUV(float3 uvw)
			{
				uvw = GetRandomTiledUV(uvw, _DistanceBetweenWalls, _Tiles);
				uvw.x = (uvw.x - 1.0) * _CeilTex_ST.x - _CeilTex_ST.z;
				uvw.y = (uvw.y) * _CeilTex_ST.y - _CeilTex_ST.w;
				return float4(-uvw.x, uvw.y,0,0);
			}

			float2 GetFloorUV(float3 uvw)
			{
				uvw = GetRandomTiledUV(uvw, _DistanceBetweenWalls, _Tiles);
				uvw.x = (uvw.x) * _FloorTex_ST.x + _FloorTex_ST.z;
				uvw.y = (uvw.y) * _FloorTex_ST.y + _FloorTex_ST.w;
				return uvw.xy;
			}

			float2 GetLeftWallUV(float3 uvw)
			{
				uvw = GetRandomTiledUV(uvw, _DistanceBetweenWalls, _Tiles);
				uvw.x = (uvw.x) * _LeftTex_ST.x + _LeftTex_ST.z;
				uvw.y = (uvw.y) * _LeftTex_ST.y + _LeftTex_ST.w;
				return uvw.xy;
			}

			float2 GetRightWallUV(float3 uvw)
			{
				uvw = GetRandomTiledUV(uvw, _DistanceBetweenWalls, _Tiles);
				uvw.x = (uvw.x - 1.0) * _RightTex_ST.x - _RightTex_ST.z;
				uvw.y = (uvw.y) * _RightTex_ST.y + _RightTex_ST.w;
				return float2(-uvw.x, uvw.y);
			}

			float2 GetFrontWallUV(float3 uvw)
			{
				uvw = GetRandomTiledUV(uvw, _DistanceBetweenWalls, _Tiles);
				uvw.x = (uvw.x) * _FrontTex_ST.x + _FrontTex_ST.z;
				uvw.y = (uvw.y) * _FrontTex_ST.y + _FrontTex_ST.w;
				return uvw.xy;
			}

			float2 GetBackWallUV(float3 uvw)
			{
				uvw = GetRandomTiledUV(uvw, _DistanceBetweenWalls, _Tiles);
				uvw.x = (uvw.x - 1.0) * _BackTex_ST.x - _BackTex_ST.z;
				uvw.y = (uvw.y) * _BackTex_ST.y + _BackTex_ST.w;
				return float2(-uvw.x, uvw.y);
			}

			//---------------------------------------------------

			//---------------------------------------------------

			// 線分と無限平面の衝突位置算出
			// http://www.scratchapixel.com/lessons/3d-basic-rendering/minimal-ray-tracer-rendering-simple-shapes/ray-plane-and-ray-disk-intersection
			// rayPos : レイの開始地点
			// rayDir : レイの向き
			// planePos : 平面の座標
			// planeNormal : 平面の法線
			float GetIntersectLength(float3 rayPos, float3 rayDir, float3 planePos, float3 planeNormal)
			{
				// 処理効率悪いので使用する側でカバー
				//if (dot(rayDir, planeNormal) <= 0)
				//	return INTERSECT_INF;

				// (p - p0)       ・n = 0
				// (L0 + L*t - p0)・n = 0
				// L*t・n + (L0 - p0)・n = 0
				// (L0 - p0)・n = - L*t・n
				// ((L0 - p0)・n) / (L・n) = -t
				// ((p0 - L0)・n) / (L・n) = t
				return dot(planePos - rayPos, planeNormal) / dot(rayDir, planeNormal);
			}

			//---------------------------------------------------

			v2f vert(appdata_base i)
			{
				v2f o;
				o.viewPos = mul(UNITY_MATRIX_MV,i.vertex);
				o.pos = mul(UNITY_MATRIX_P, float4(o.viewPos, 1.0));
				o.normal = i.normal;

				// カメラから頂点位置への方向を求める（オブジェクト空間）
				o.objectViewDir = -ObjSpaceViewDir(i.vertex);
				o.objectPos = i.vertex+_Offset + _OffsetVec*_Time.y;
				o.uv = i.texcoord;
					
				return o;
			}

			half4 frag(v2f i) : SV_TARGET
			{
				float3 rayDir = normalize(i.objectViewDir);
				float3 rayPos = i.objectPos + rayDir * _ZPlusVal; // 微妙に内側に入れることでZファイティングを防ぐ
				float3 planePos = float3(0, 0, 0);
				float3 planeNormal = float3(0, 0, 0);
				float depth = INTERSECT_INF;
				fixed4 color = fixed4(0,0,0,0);
				fixed4 sample;

				const float3 UpVec = float3(0, 1, 0);
				const float3 RightVec = float3(1, 0, 0);
				const float3 FrontVec = float3(0, 0, 1);

				{//Floor,Ceil
					float which = step(0.0, dot(rayDir, UpVec));
					planeNormal = float3(0, lerp(1, -1, which), 0);
					planePos.xyz = 0.0;
					planePos.y = ceil(rayPos.y / _RoomScale.y);
					planePos.y -= lerp(1.0, 0.0, which);
					planePos.y *= _RoomScale.y;

					float i = GetIntersectLength(rayPos, rayDir, planePos, planeNormal);
					if (i < depth)
					{

						float3 pos = rayPos + rayDir * i + 0.5;
						float3 uvw = pos.xzy;
						if(dot(rayDir,UpVec)>0){
							sample = tex2D(_CeilTex, GetCeilUV(uvw));
						}else{
							sample = tex2D(_FloorTex, GetFloorUV(uvw));
						}
						if(sample.a>0){
							color = sample;
							depth = i;
						}
					}
				}
						
				// 左右の壁
				{
					float which = step(0.0, dot(rayDir, RightVec));
					planeNormal = float3(lerp(1, -1, which), 0, 0);
					planePos.xyz = 0.0;
					planePos.x = ceil(rayPos.x / _RoomScale.x);
					planePos.x -= lerp(1.0, 0.0, which);
					planePos.x *= _RoomScale.x;

					float i = GetIntersectLength(rayPos, rayDir, planePos, planeNormal);
					if (i < depth)
					{
						float3 pos = rayPos + rayDir * i + 0.5;
						float3 uvw = pos.zyx;
						if(dot(rayDir,RightVec)>0){
							sample = tex2D(_RightTex, GetRightWallUV(uvw));
						}else{
							sample = tex2D(_LeftTex, GetLeftWallUV(uvw));
						}
						if(sample.a>0){
							color = sample;
							depth = i;
						}
					}
				}
						
				// 奥の壁
				{
					float which = step(0.0, dot(rayDir, FrontVec));
					planeNormal = float3(0, 0, lerp(1, -1, which));
					planePos.xyz = 0.0;
					planePos.z = ceil(rayPos.z / _RoomScale.z);
					planePos.z -= lerp(1.0, 0.0, which);
					planePos.z *= _RoomScale.z;

					float i = GetIntersectLength(rayPos, rayDir, planePos, planeNormal);
					if (i < depth)
					{
						float3 pos = rayPos + rayDir * i + 0.5;
						float3 uvw = pos.xyz;
						if(dot(rayDir,FrontVec)>0){
						sample = tex2D(_FrontTex, GetFrontWallUV(uvw));
						}else{
						sample = tex2D(_BackTex, GetBackWallUV(uvw));
						}
						if(sample.a>0){
							color = sample;
							depth = i;
						}
					}
				}

				fixed4 maincol = tex2D(_MainTex,i.uv)*_Color;

				return lerp(color,maincol,maincol.a);
			}
			ENDCG
		}
	}
}