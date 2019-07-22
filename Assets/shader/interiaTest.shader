Shader "Custom/InteriorMappingTest" 
{
	Properties 
	{
		_RoomScale ("RoomScale",vector) = (1,1,1,1)
		_Offset ("Offset", Vector) = (0,0,0,0)
		_OffsetVec ("OffsetVec", Vector) = (0,0,0,0)
		_MainTex("Main Texture", 2D) = "white"{}
		[HDR]_Color ("color",color) = (0,0,0,0)
		_CeilTex("Ceil Texture", 2D) = "white"{}
		_CeilColor ("color",color) = (1,1,1,1)
		_FloorTex("Floor Texture", 2D) = "white"{}
		_FloorColor ("color",color) = (1,1,1,1)
		_RightTex("Right Texture", 2D) = "white"{}
		_RightColor ("color",color) = (1,1,1,1)
		_LeftTex("Left Texture", 2D) = "white"{}
		_LeftColor ("color",color) = (1,1,1,1)
		_BackTex("Back Texture", 2D) = "white"{}
		_BackColor ("color",color) = (1,1,1,1)
		_FrontTex("Front Texture", 2D) = "white"{}
		_FrontColor ("color",color) = (1,1,1,1)
		_Tiles ("_Tiles", Float) = 0.25
		_DistanceBetweenWalls ("_Tiles", Float) = 0.25
		_ZPlusVal ("ZPlusVal",range(0,1)) = 0.0001
		[HideInInspector]_UpVec ("UpVec", Vector) = (0,1,0,0)
		[HideInInspector]_RightVec ("RightVec", Vector) = (1,0,0,0)
		[HideInInspector]_BackVec ("BackVec", Vector) = (0,0,1,0)
		_ObjRate ("ObjRate",range(0,1)) = 1
		_FrontObjTex ("Obj Texture", 2D) = "white"{}
		_FrontObjColor ("color",color) = (1,1,1,0)
		_FrontObjVec ("FrontObjVec",vector) = (0,0,1,0)
		_FrontObjOffset ("Onj Offset",Vector) = (0,0,0,0)
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
			#define INTERSECT_INF 2147483647

			float4 _Offset,_OffsetVec;
			sampler2D _MainTex;
			float4 _MainTex_ST;
			float4 _Color;
			sampler2D _FloorTex, _CeilTex, _FrontTex, _BackTex, _RightTex, _LeftTex, _FrontObjTex;
			float4 _FloorTex_ST, _CeilTex_ST, _FrontTex_ST, _BackTex_ST, _RightTex_ST, _LeftTex_ST, _FrontObjTex_ST;
			float4 _FloorColor, _CeilColor, _RightColor, _LeftColor, _FrontColor, _BackColor, _FrontObjColor;
			float4 _RoomScale;
			float _ObjRate;
			float4 _UpVec, _RightVec, _BackVec;
			float4 _FrontObjVec;
			float4 _FrontObjOffset;
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

			float3 GetRandomTiledUV(float3 pos, float3 between, float4 st)
			{
				float tile = st.x*st.y ;
				float r = rand(float3(floor( pos.x/between.x + _ZPlusVal), floor( pos.y/between.y + _ZPlusVal), floor(pos.z/between.z + _ZPlusVal)));
				r = floor(r*tile) % tile;
					
				float3 uvw = pos;
				uvw.xy = frac(uvw.xy / between);
				uvw.x += floor(r / st.x);
				uvw.y += floor(r % st.x);
				uvw.x /= st.x;
				uvw.y /= st.y;
				uvw.z = r;
					
				return uvw;
			}

			float3 GetRandomObjUV(float3 pos, float3 between, float4 st)
			{
				float tile = st.x*st.y * 1/_ObjRate;
				float r = rand(float3(floor( pos.x/between.x + _ZPlusVal), floor( pos.y/between.y + _ZPlusVal), floor(pos.z/between.z + _ZPlusVal)));
				if(r>_ObjRate) return 0;
				r = floor(r*tile) % tile;

					
				float3 uvw = pos;
				uvw.xy = frac(uvw.xy / between);
				uvw.x += floor(r / st.x);
				uvw.y += floor(r % st.x);
				uvw.x /= st.x;
				uvw.y /= st.y;
				uvw.z = r;
					
				return uvw;
			}

			float2 GetCeilUV(float3 pos)
			{
				float3 uvw = GetRandomTiledUV(pos.xzy, _RoomScale.xzy, _CeilTex_ST);
				uvw.x = (uvw.x - 1.0) - _CeilTex_ST.z ;
				uvw.y = (uvw.y) - _CeilTex_ST.w ;
				return float2(-uvw.x, uvw.y);
			}

			float2 GetFloorUV(float3 pos)
			{
				float3 uvw = GetRandomTiledUV(pos.xzy, _RoomScale.xzy, _FloorTex_ST);
				uvw.x = (uvw.x) + _FloorTex_ST.z;
				uvw.y = (uvw.y) + _FloorTex_ST.w;
				return uvw.xy;
			}

			float2 GetRightWallUV(float3 pos)
			{
				float3 uvw = GetRandomTiledUV(pos.zyx, _RoomScale.zyx, _RightTex_ST);
				uvw.x = (uvw.x - 1.0) - _RightTex_ST.z;
				uvw.y = (uvw.y) + _RightTex_ST.w;
				return float2(-uvw.x, uvw.y);
			}

			float2 GetLeftWallUV(float3 pos)
			{
				float3 uvw = GetRandomTiledUV(pos.zyx, _RoomScale.zyx,  _LeftTex_ST);
				uvw.x = (uvw.x) + _LeftTex_ST.z;
				uvw.y = (uvw.y) + _LeftTex_ST.w;
				return uvw.xy;
			}

			float2 GetBackWallUV(float3 pos)
			{
				float3 uvw = GetRandomTiledUV(pos.xyz, _RoomScale.xyz, _BackTex_ST);
				uvw.x = (uvw.x - 1.0) - _BackTex_ST.z;
				uvw.y = (uvw.y) + _BackTex_ST.w;
				return float2(-uvw.x, uvw.y);
			}

			float2 GetFrontWallUV(float3 pos)
			{
				float3 uvw = GetRandomTiledUV(pos.xyz, _RoomScale.xyz, _FrontTex_ST);
				uvw.x = (uvw.x) + _FrontTex_ST.z;
				uvw.y = (uvw.y) + _FrontTex_ST.w;
				return uvw.xy;
			}

			float2 GetFrontObjUV(float3 pos, float3 vec)
			{
				float3 posSam = pos.xyz*vec.z + pos.xzy*vec.y + pos.zyx*vec.x;
				float3 scaleSam = _RoomScale.xyz*vec.z + _RoomScale.xzy*vec.y + _RoomScale.zyx*vec.x;
				float3 uvw = GetRandomObjUV(posSam,scaleSam,_FrontObjTex_ST);
				uvw.x = (uvw.x) - _FrontObjTex_ST.z;
				uvw.y = (uvw.y) + _FrontObjTex_ST.w;
				return uvw.xy;
			}

			float GetIntersectLength(float3 rayPos, float3 rayDir, float3 planePos, float3 planeNormal)
			{
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
				fixed4 sampleCol;

				{//Floor,Ceil
					float which = step(0.0, dot(rayDir, _UpVec.xyz));
					planeNormal = _UpVec.xyz*lerp(1, -1, which);
					planePos.xyz = 0.0;
					planePos.y = ceil(rayPos.y / _RoomScale.y);
					planePos.y -= lerp(1.0, 0.0, which);
					planePos.y *= _RoomScale.y;

					float i = GetIntersectLength(rayPos, rayDir, planePos, planeNormal);
					if (i < depth)
					{

						float3 pos = rayPos + rayDir * i;
						if(dot(rayDir,_UpVec.xyz)>0){
							sampleCol = tex2D(_CeilTex, GetCeilUV(pos)) * _CeilColor;
						}else{
							sampleCol = tex2D(_FloorTex, GetFloorUV(pos)) * _FloorColor;
						}
						if(sampleCol.a>0){
							color = sampleCol;
							depth = i;
						}
					}
				}
						
				// 左右の壁
				{
					float which = step(0.0, dot(rayDir, _RightVec.xyz));
					planeNormal = _RightVec.xyz*lerp(1, -1, which);
					planePos.xyz = 0.0;
					planePos.x = ceil(rayPos.x / _RoomScale.x);
					planePos.x -= lerp(1.0, 0.0, which);
					planePos.x *= _RoomScale.x;

					float i = GetIntersectLength(rayPos, rayDir, planePos, planeNormal);
					if (i < depth)
					{
						float3 pos = rayPos + rayDir * i;
						if(dot(rayDir,_RightVec.xyz)>0){
							sampleCol = tex2D(_RightTex, GetRightWallUV(pos)) * _RightColor;
						}else{
							sampleCol = tex2D(_LeftTex, GetLeftWallUV(pos)) * _LeftColor;
						}
						if(sampleCol.a>0){
							color = sampleCol;
							depth = i;
						}
					}
				}
						
				// 奥の壁
				{
					float which = step(0.0, dot(rayDir, _BackVec.xyz));
					planeNormal = _BackVec.xyz*lerp(1, -1, which);
					planePos.xyz = 0.0;
					planePos.z = ceil(rayPos.z / _RoomScale.z);
					planePos.z -= lerp(1.0, 0.0, which);
					planePos.z *= _RoomScale.z;

					float i = GetIntersectLength(rayPos, rayDir, planePos, planeNormal);
					if (i < depth)
					{
						float3 pos = rayPos + rayDir * i;
						if(dot(rayDir,_BackVec.xyz)>0){
						sampleCol = tex2D(_FrontTex, GetFrontWallUV(pos)) * _FrontColor;
						}else{
						sampleCol = tex2D(_BackTex, GetBackWallUV(pos)) * _BackColor;
						}
						if(sampleCol.a>0){
							color = sampleCol;
							depth = i;
						}
					}
				}

				//書き割り
				{
					float3 ObjVec = normalize(_FrontObjVec);
					float which = 0;//step(0.0, dot(rayDir, ObjVec.xyz));
					planeNormal = ObjVec.xyz*lerp(1, -1, which);
					planePos.xyz = 0.0;
					planePos = ObjVec * ceil(rayPos / _RoomScale);
					planePos -= ObjVec * lerp(1.0, 0.0, which);
					planePos.x *= dot(_RoomScale.x,float3(1,0,0));
					planePos.y *= dot(_RoomScale.y,float3(0,1,0));
					planePos.z *= dot(_RoomScale.z,float3(0,0,1));
					planePos += _RoomScale*_FrontObjOffset;

					//planePos.x += frac(abs(i.objectPos.x)*_RoomScale.x)*_RoomScale.x*planeNormal.x;
					//planePos.y += frac(abs(i.objectPos.y)*_RoomScale.y)*_RoomScale.y*planeNormal.y;
					//planePos.z += frac(abs(i.objectPos.z)*_RoomScale.z)*_RoomScale.z*planeNormal.z;

					float i = GetIntersectLength(rayPos, rayDir, planePos, planeNormal);
					if (i < depth && i >0)
					{
						float3 pos = rayPos + rayDir * i;
						sampleCol = tex2D(_FrontObjTex, GetFrontObjUV(pos,ObjVec)) * _FrontObjColor;
								
						if(sampleCol.a>0.3)
						{
							color = sampleCol;
							depth = i;
						}
					}
				}
				
				fixed4 maincol = tex2D(_MainTex,TRANSFORM_TEX(i.uv, _MainTex))*_Color;

				return lerp(color,maincol,maincol.a);
			}
			ENDCG
		}
	}
}