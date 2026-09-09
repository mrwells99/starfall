"""Portable packed surface maps for the reference-based Vanguard build."""
N=1024;v,u=np.mgrid[0:1:complex(N),0:1:complex(N)];rng=np.random.default_rng(928)
grain=rng.uniform(-1,1,(N,N));cloud=np.zeros((N,N))
for k in range(16):
 a,b=rng.uniform(4,130,2);cloud+=np.sin(u*a+np.sin(v*b*.5)+rng.uniform(0,6.28))*np.cos(v*b)/(k+5)
cloud=np.clip(.5+cloud*.32,0,1)
def tex_image(name,filename,rgb,noncolor=False):
 data=np.ones((N,N,4),dtype=np.float32);data[:,:,:3]=rgb
 # Floating-point storage preserves linear inputs when saving sRGB color PNGs.
 # Byte-buffer images otherwise export the darker raw values to the game.
 im=bpy.data.images.new(name,width=N,height=N,float_buffer=True)
 if noncolor:im.colorspace_settings.name='Non-Color'
 im.pixels.foreach_set(np.clip(data,0,1).ravel());im.filepath_raw=os.path.join(OUT,filename);im.file_format='PNG';im.save();im.pack();return im
def tex_bind(m,im,socket):
 nt=m.node_tree;node=nt.nodes.new('ShaderNodeTexImage');node.image=im;nt.links.new(node.outputs['Color'],nt.nodes.get('Principled BSDF').inputs[socket]);return node
# Faint bronze oxidation, small pits and irregular hairline scratches in dark steel.
scuff=np.zeros((N,N));pits=np.maximum(0,grain-.985)*8
for k in range(380):
 x,y=rng.integers(8,N-42,2);length=int(rng.integers(4,35));slant=rng.uniform(-.45,.45)
 for d in range(length):scuff[y+int(d*slant),x+d]+=float(rng.uniform(.035,.15))*sin(pi*d/length)
rgb=np.empty((N,N,3),dtype=np.float32)
for c,value in enumerate([.071,.078,.091]):rgb[:,:,c]=value+cloud*.17+grain*.018+scuff*1.8-pits*.18
steel_map=tex_image('Vanguard worn void steel','vanguard_steel.png',rgb);tex_bind(steel,steel_map,'Base Color')
rough=.40+.19*cloud+grain*.012+np.minimum(.15,pits)-scuff*.15
tex_bind(steel,tex_image('Vanguard forged roughness','vanguard_roughness.png',np.repeat(rough[:,:,None],3,axis=2),True),'Roughness')
# The same forged grain carries through the bronze-colored retaining hardware.
tex_bind(edge,tex_image('Vanguard weathered celestial alloy','vanguard_alloy.png',rgb*np.array([1.95,1.48,.97])),'Base Color')
# Navy astral cloth; gold symbols are actual mesh embroidery.
weave=np.sin(u*2500)*np.sin(v*2700)*.005
for c,value in enumerate([.040,.050,.082]):rgb[:,:,c]=value+cloud*[.024,.027,.042][c]+weave
cloth_map=tex_image('Vanguard navy astral weave','vanguard_cloth.png',rgb);tex_bind(cloth,cloth_map,'Base Color')
height=.30*np.sin(u*1600)+.29*np.sin(v*1800)+grain*.10;gy,gx=np.gradient(height);norm=np.dstack((-gx*.30,-gy*.30,np.ones((N,N))));norm/=np.linalg.norm(norm,axis=2)[:,:,None]
normal_map=tex_image('Vanguard cloth weave normals','vanguard_fabric_normal.png',norm*.5+.5,True)
for m,strength in [(cloth,.35),(leather,.16)]:
 nt=m.node_tree;im=nt.nodes.new('ShaderNodeTexImage');im.image=normal_map;nm=nt.nodes.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=strength;nt.links.new(im.outputs['Color'],nm.inputs['Color']);nt.links.new(nm.outputs['Normal'],nt.nodes.get('Principled BSDF').inputs['Normal'])
# Crystal veins follow a warped Voronoi fracture pattern, packed for GLB portability.
nearest=np.full((N,N),100.);second=np.full((N,N),100.)
uu=u+.013*np.sin(v*35);vv=v+.017*np.sin(u*29)
for x,y in rng.uniform(-.2,1.2,(56,2)):
 d=(uu-x)**2+(vv-y)**2;second=np.minimum(second,np.maximum(nearest,d));nearest=np.minimum(nearest,d)
cracks=np.exp(-np.maximum(0,np.sqrt(second)-np.sqrt(nearest))*520)
fog=np.clip(cloud+.16*np.sin(u*27+v*18),0,1)
rgb[:,:,0]=.075+.13*fog+cracks*.62;rgb[:,:,1]=.012+.025*fog+cracks*.24;rgb[:,:,2]=.20+.28*fog+cracks*.65
crystal_map=tex_image('Vanguard violet fractured amethyst','vanguard_amethyst.png',rgb)
tex_bind(crystal,crystal_map,'Base Color');tex_bind(crystal,crystal_map,'Emission Color')
crystal.node_tree.nodes.get('Principled BSDF').inputs['Emission Strength'].default_value=1.4
void.node_tree.nodes.get('Principled BSDF').inputs['Specular IOR Level'].default_value=0
