Shader "Custom/InteriorMappingTest" 
{
	Properties 
	{
		_MainTex("Main Texture", 2D) = "white"{}
		[HDR]_Color ("color",color) = (1,1,1,1)
		_FloorTex("Floor Texture", 2D) = "white"{}
		_CeilTex("Ceil Texture", 2D) = "white"{}
		_FrontTex("Front Texture", 2D) = "white"{}
		_BackTex("Back Texture", 2D) = "white"{}
		_RightTex("Right Texture", 2D) = "white"{}
		_LeftTex("Left Texture", 2D) = "white"{}
		_FloorTexSizeAndOffset ("Floor Texture Size And Offset", Vector) = (0.5, 0.5, 0.0, 0.0)
		_CeilTexSizeAndOffset ("Ceil Texture Size And Offset", Vector) = (0.5, 0.5, 0.0, 0.5)
		_WallTexSizeAndOffset ("Wall Texture Size And Offset", Vector) = (0.5, 0.5, 0.5, 0.0)
		_DistanceBetweenFloors ("Distance Between Floors", Float) = 0.25
		_DistanceBetweenWalls ("Distance Between Walls", Float) = 0.25
		_Tiles ("_Tiles", Float) = 0.25
	}
	
	SubShader 
	{
		Tags
		{
			"RenderType"="Opaque"
		}
		Cull off
		
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"
			#define INTERSECT_INF 999

			sampler2D _MainTex;
			float4 _Color;
			sampler2D _FloorTex, _CeilTex, _FrontTex, _BackTex, _RightTex, _LeftTex;
			float4 _FloorTexSizeAndOffset, _CeilTexSizeAndOffset, _WallTexSizeAndOffset;
			float _DistanceBetweenFloors, _DistanceBetweenWalls;
			float _Tiles;

			struct v2f
			{
				float4 pos : SV_POSITION;
				float3 normal : TEXCOORD0;
				float3 viewPos : TEXCOORD1;
				float3 objectViewDir : TEXCOORD2;
				float3 objectPos : TEXCOORD3;
			};

			//---------------------------------------------------
			float rand(float3 co)
			{
				return frac(sin(dot(co.xyz, float3(12.9898, 78.233, 56.787))) * 43758.5453);
			}

			float3 GetRandomTiledUV(float3 uvw, float between, float tile)
			{
				float r = rand(floor((uvw + 0.00001) / between)); // 微妙に内側に入れることでZファイティングを防ぐ
				r = floor(r * 10000) % tile;
					
				uvw.xy = frac(uvw.xy / between);
				uvw.x += floor(r / (tile / 2));
				uvw.y += floor(r % (tile / 2));
				uvw.xy = uvw.xy / (tile / 2);
				uvw.z = r;
					
				return uvw;
			}

			float2 GetCeilUV(float3 uvw)
			{
				uvw = GetRandomTiledUV(uvw, _DistanceBetweenWalls, _Tiles);
				uvw.x = (uvw.x - 1.0) * _CeilTexSizeAndOffset.x - _CeilTexSizeAndOffset.z;
				uvw.y = (uvw.y) * _CeilTexSizeAndOffset.y - _CeilTexSizeAndOffset.w;
				return float2(-uvw.x, uvw.y);
			}

			float2 GetFloorUV(float3 uvw)
			{
				uvw = GetRandomTiledUV(uvw, _DistanceBetweenWalls, _Tiles);
				uvw.x = (uvw.x) * _FloorTexSizeAndOffset.x + _FloorTexSizeAndOffset.z;
				uvw.y = (uvw.y) * _FloorTexSizeAndOffset.y + _FloorTexSizeAndOffset.w;
				return uvw.xy;
			}

			float2 GetLeftWallUV(float3 uvw)
			{
				uvw = GetRandomTiledUV(uvw, _DistanceBetweenWalls, _Tiles);
				uvw.x = (uvw.x) * _WallTexSizeAndOffset.x + _WallTexSizeAndOffset.z;
				uvw.y = (uvw.y) * _WallTexSizeAndOffset.y + _WallTexSizeAndOffset.w;
				return uvw.xy;
			}

			float2 GetRightWallUV(float3 uvw)
			{
				uvw = GetRandomTiledUV(uvw, _DistanceBetweenWalls, _Tiles);
				uvw.x = (uvw.x - 1.0) * _WallTexSizeAndOffset.x - _WallTexSizeAndOffset.z;
				uvw.y = (uvw.y) * _WallTexSizeAndOffset.y + _WallTexSizeAndOffset.w;
				return float2(-uvw.x, uvw.y);
			}

			float2 GetFrontWallUV(float3 uvw)
			{
				uvw = GetRandomTiledUV(uvw, _DistanceBetweenWalls, _Tiles);
				uvw.x = (uvw.x) * _WallTexSizeAndOffset.x + _WallTexSizeAndOffset.z;
				uvw.y = (uvw.y) * _WallTexSizeAndOffset.y + _WallTexSizeAndOffset.w;
				return uvw.xy;
			}

			float2 GetBackWallUV(float3 uvw)
			{
				uvw = GetRandomTiledUV(uvw, _DistanceBetweenWalls, _Tiles);
				uvw.x = (uvw.x - 1.0) * _WallTexSizeAndOffset.x - _WallTexSizeAndOffset.z;
				uvw.y = (uvw.y) * _WallTexSizeAndOffset.y + _WallTexSizeAndOffset.w;
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
				o.viewPos = UnityObjectToViewPos(i.vertex);
				o.pos = mul(UNITY_MATRIX_P, float4(o.viewPos, 1.0));
				o.normal = i.normal;

				// カメラから頂点位置への方向を求める（オブジェクト空間）
				o.objectViewDir = -ObjSpaceViewDir(i.vertex);
				o.objectPos = i.vertex;
					
				return o;
			}

			half4 frag(v2f i) : SV_TARGET
			{
				float3 rayDir = normalize(i.objectViewDir);
				float3 rayPos = i.objectPos + rayDir * 0.0001; // 微妙に内側に入れることでZファイティングを防ぐ
				float3 planePos = float3(0, 0, 0);
				float3 planeNormal = float3(0, 0, 0);
				float intersect = INTERSECT_INF;
				float3 color = float3(0,0,0);

				const float3 UpVec = float3(0, 1, 0);
				const float3 RightVec = float3(1, 0, 0);
				const float3 FrontVec = float3(0, 0, 1);

				// 床と天井
				{
					float which = step(0.0, dot(rayDir, UpVec));
					planeNormal = float3(0, lerp(1, -1, which), 0);
					planePos.xyz = 0.0;
					planePos.y = ceil(rayPos.y / _DistanceBetweenFloors);
					planePos.y -= lerp(1.0, 0.0, which);
					planePos.y *= _DistanceBetweenFloors;

					float i = GetIntersectLength(rayPos, rayDir, planePos, planeNormal);
					if (i < intersect)
					{
						intersect = i;

						float3 pos = rayPos + rayDir * i + 0.5;
						float3 uvw = pos.xzy;
						//if(planeNormal)
						color = tex2D(_MainTex, GetCeilUV(uvw));
					}
				}
						
				// 左右の壁
				{
					float which = step(0.0, dot(rayDir, RightVec));
					planeNormal = float3(lerp(1, -1, which), 0, 0);
					planePos.xyz = 0.0;
					planePos.x = ceil(rayPos.x / _DistanceBetweenWalls);
					planePos.x -= lerp(1.0, 0.0, which);
					planePos.x *= _DistanceBetweenWalls;

					float i = GetIntersectLength(rayPos, rayDir, planePos, planeNormal);
					if (i < intersect)
					{
						intersect = i;
						float3 pos = rayPos + rayDir * i + 0.5;
						float3 uvw = pos.zyx;
						color = tex2D(_MainTex, GetRightWallUV(uvw));
					}
				}
						
				// 奥の壁
				{
					float which = step(0.0, dot(rayDir, FrontVec));
					planeNormal = float3(0, 0, lerp(1, -1, which));
					planePos.xyz = 0.0;
					planePos.z = ceil(rayPos.z / _DistanceBetweenWalls);
					planePos.z -= lerp(1.0, 0.0, which);
					planePos.z *= _DistanceBetweenWalls;

					float i = GetIntersectLength(rayPos, rayDir, planePos, planeNormal);
					if (i < intersect)
					{
						intersect = i;
						float3 pos = rayPos + rayDir * i + 0.5;
						float3 uvw = pos.xyz;
						color = tex2D(_MainTex, GetBackWallUV(uvw));
					}
				}

				return half4(color*_Color, 1);
			}
			ENDCG
		}
	}
}