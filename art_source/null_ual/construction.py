def mesh(name,verts,faces,material,weights,uvs=None,smooth=True):
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
    ob=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(ob);me.materials.append(material)
    for p in me.polygons:p.use_smooth=smooth
    uv=me.uv_layers.new(name='UVMap')
    for p in me.polygons:
        for li in p.loop_indices:
            idx=me.loops[li].vertex_index;co=me.vertices[idx].co
            uv.data[li].uv=uvs[idx] if uvs else (co.x*2+co.y,co.z*2+co.y)
    for i in range(len(verts)):
        ws=weights[i] if isinstance(weights,list) else weights
        total=sum(ws.values())
        for bn,w in ws.items():
            if w>0:(ob.vertex_groups.get(bn) or ob.vertex_groups.new(name=bn)).add([i],w/total,'REPLACE')
    ob.parent=rig;mod=ob.modifiers.new('Preset deformation','ARMATURE');mod.object=rig
    parts.append(ob);return ob
def surface(name,fn,nu,nv,material,weight,thickness=0):
    verts=[];weights=[];uv=[];faces=[]
    for j in range(nv+1):
        for i in range(nu+1):
            a=i/nu;b=j/nv;p=fn(a,b);verts.append(p);uv.append((a,b));weights.append(weight(a,b,p) if callable(weight) else weight)
    for j in range(nv):
        for i in range(nu):
            k=j*(nu+1)+i;faces.append((k,k+1,k+nu+2,k+nu+1))
    ob=mesh(name,verts,faces,material,weights,uv)
    if thickness:
        mod=ob.modifiers.new('Garment thickness','SOLIDIFY');mod.thickness=thickness
        bpy.context.view_layer.objects.active=ob
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return ob
def ellipsoid(name,c,r,m,bn):
    return surface(name,lambda a,b:(c[0]+r[0]*math.sin(math.pi*b)*math.cos(math.tau*a),c[1]+r[1]*math.sin(math.pi*b)*math.sin(math.tau*a),c[2]+r[2]*math.cos(math.pi*b)),24,14,m,{bn:1})

def armor_shell(name,c,r,m,bn,axis='Z'):
    # Fabricated eight-sided shells with broad faces and a narrow rolled bevel.
    # Coordinates fit the unchanged mannequin; the body/rig are never resized.
    c=Vector(c);verts=[];faces=[];steps=[(-1,.87),(-.87,1),(.73,1),(1,.90)];sides=16
    for height,radius in steps:
        for i in range(sides):
            a=math.tau*(i+.5)/sides
            q=Vector((r[0]*radius*math.cos(a),r[1]*radius*math.sin(a),r[2]*height))
            if axis=='X':q=Vector((q.z,q.y,q.x))
            verts.append(c+q)
    for row in range(3):
        for i in range(sides):faces.append((row*sides+i,row*sides+(i+1)%sides,(row+1)*sides+(i+1)%sides,(row+1)*sides+i))
    faces.extend([tuple(range(sides-1,-1,-1)),tuple(range(3*sides,4*sides))])
    ob=mesh(name,verts,faces,m,{bn:1},smooth=True)
    for p in ob.data.polygons:
        if p.index>=3*sides:p.use_smooth=False
    mod=ob.modifiers.new('Plate edge radii','BEVEL');mod.width=.002;mod.segments=2
    bpy.context.view_layer.objects.active=ob;bpy.ops.object.modifier_apply(modifier=mod.name)
    return ob
def tube(name,points,r,m,bn,sides=8):
    verts=[];faces=[]
    for i,pt in enumerate(points):
        p=Vector(pt);d=(Vector(points[min(i+1,len(points)-1)])-Vector(points[max(i-1,0)])).normalized()
        x=d.cross(Vector((0,1,0)))
        if x.length<.01:x=d.cross(Vector((1,0,0)))
        x.normalize();y=d.cross(x)
        for j in range(sides):verts.append(p+r*(x*math.cos(math.tau*j/sides)+y*math.sin(math.tau*j/sides)))
    for i in range(len(points)-1):
        for j in range(sides):
            k=i*sides+j;l=i*sides+(j+1)%sides;faces.append((k,l,l+sides,k+sides))
    faces += [tuple(range(sides-1,-1,-1)),tuple((len(points)-1)*sides+j for j in range(sides))]
    return mesh(name,verts,faces,m,{bn:1})
def ring(name,c,rx,rz,m,bn,r=.004):
    return tube(name,[(c[0]+rx*math.sin(math.tau*i/64),c[1],c[2]+rz*math.cos(math.tau*i/64)) for i in range(65)],r,m,bn)
def star(name,c,size,m,bn):
    pts=[]
    for i in range(17):
        a=math.tau*i/16;s=size if i%2==0 else size*.25
        if i%4==2:s*=.65
        pts.append((c[0]+math.sin(a)*s,c[1],c[2]+math.cos(a)*s))
    return mesh(name,[(c[0],c[1]-.003,c[2])]+pts,[(0,i+1,i+2) for i in range(16)],m,{bn:1},smooth=False)
def panel(name,points,m,bn,thickness=.006):
    n=len(points);verts=points+[(x,y+thickness,z) for x,y,z in points]
    faces=[tuple(range(n)),tuple(range(2*n-1,n-1,-1))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    ob=mesh(name,verts,faces,m,{bn:1},smooth=False)
    mod=ob.modifiers.new('Forged bevel','BEVEL');mod.width=.003;mod.segments=2
    bpy.context.view_layer.objects.active=ob;bpy.ops.object.modifier_apply(modifier=mod.name)
    return ob
