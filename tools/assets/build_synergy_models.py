"""Offline editable low-poly scene/icon authoring. No runtime Python dependency."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
COLORS = dict(skin='#cdb893', iron='#617075', dark='#34464b', rat='#887a70', rose='#b37b78',
              guardian='#738ba4', mage='#8c4054', glow='#bc6977', wing='#80968e', scout='#738d69',
              gold='#c49c56', saboteur='#a66b45', leather='#65554a', white='#ece4ce')
def color(value):
    h=COLORS.get(value,value).lstrip('#');return ', '.join(str(round(int(h[i:i+2],16)/255,6)) for i in (0,2,4))+', 1'
class Scene:
    def __init__(self,key):self.key=key;self.resources=[];self.nodes=[];self.index=0
    def part(self,name,shape,material,pos,size,parent='.',gait=None,wing=None,rotation=None):
        self.index+=1;i=self.index
        mesh=f'mesh{i}';mat=f'mat{i}'
        if shape=='box':spec=f'type="BoxMesh" id="{mesh}"]\nsize = Vector3{size}'
        elif shape=='prism':spec=f'type="PrismMesh" id="{mesh}"]\nsize = Vector3{size}'
        elif shape=='sphere':spec=f'type="SphereMesh" id="{mesh}"]\nradius = {size[0]/2}\nheight = {size[1]}\nradial_segments = 8\nrings = 4'
        else:spec=f'type="CylinderMesh" id="{mesh}"]\ntop_radius = {size[0]}\nbottom_radius = {size[2]}\nheight = {size[1]}\nradial_segments = 8'
        self.resources += [f'[sub_resource type="StandardMaterial3D" id="{mat}"]\nalbedo_color = Color({color(material)})\nroughness = 0.95',f'[sub_resource {spec}']
        n=f'[node name="{name}" type="MeshInstance3D" parent="{parent}"]\nposition = Vector3{pos}\nmesh = SubResource("{mesh}")\nmaterial_override = SubResource("{mat}")'
        if shape=='sphere' and size[2]!=size[0]:n+=f'\nscale = Vector3(1, 1, {size[2]/size[0]})'
        if gait is not None:n+=f'\nmetadata/gait = {gait}'
        if wing is not None:n+=f'\nmetadata/wing = {wing}'
        if rotation:n+=f'\nrotation = Vector3{rotation}'
        self.nodes.append(n)
    def humanoid(self,coat,wide=False):
        self.part('Coat','cylinder',coat,(0,.4,0),(.19,.48,.3 if wide else .23))
        self.part('Head','sphere','skin',(0,.78,-.01),(.3,.3,.3))
        for sign in [-1,1]:
            self.part('Leg'+str(sign),'box','dark',(sign*.1,.13,0),(.11,.25,.14),gait=sign)
            self.part('Arm'+str(sign),'box',coat,(sign*(.28 if wide else .23),.45,0),(.12,.34,.13),gait=-sign)
    def save(self):
        root=f'[node name="{self.key.title().replace("_","")}" type="Node3D"]\nscript = ExtResource("1")'
        if self.key=='winged_beast':root+='\nflying = true'
        text='[gd_scene load_steps='+str(len(self.resources)+2)+' format=3]\n\n[ext_resource type="Script" path="res://scripts/enemies/rendering/miniature_enemy.gd" id="1"]\n\n'+'\n\n'.join(self.resources+[root]+self.nodes)+'\n'
        (ROOT/'assets/models/enemies'/f'{self.key}.tscn').write_text(text,encoding='utf-8')
def models():
    s=Scene('rat_swarm')
    s.part('Body','sphere','rat',(0,.2,0),(.29,.3,.54));s.part('Snout','prism','rat',(0,.19,-.31),(.23,.18,.27))
    for sign in [-1,1]:
        s.part('Ear'+str(sign),'sphere','rose',(sign*.13,.35,-.19),(.14,.18,.08))
        s.part('Eye'+str(sign),'sphere','dark',(sign*.1,.24,-.3),(.045,.045,.045))
        for back in [-1,1]:s.part(f'Paw{sign}{back}','box','rose',(sign*.13,.06,back*.18),(.07,.1,.13),gait=sign*back)
    s.part('Tail','box','rose',(.04,.06,.4),(.045,.045,.37),rotation=(0,.25,0));s.save()
    s=Scene('shield_guardian');s.humanoid('guardian',True)
    s.part('Helmet','cylinder','iron',(0,.86,0),(.17,.18,.2));s.part('Crest','box','gold',(0,1.02,0),(.08,.2,.22))
    s.part('TowerShield','box','iron',(-.12,.48,-.25),(.52,.7,.1));s.part('ShieldFace','box','guardian',(-.12,.49,-.31),(.43,.59,.025))
    s.part('ShieldCross','box','white',(-.12,.49,-.33),(.06,.45,.02));s.part('Mace','sphere','iron',(.33,.62,-.19),(.2,.2,.2));s.save()
    s=Scene('blood_mage');s.humanoid('mage',True)
    s.part('Hood','cylinder','mage',(0,.85,.03),(.05,.32,.22));s.part('Staff','box','leather',(.3,.53,-.12),(.045,1,.045))
    s.part('BloodCrystal','prism','glow',(.3,1.1,-.12),(.18,.3,.15));s.part('Collar','box','gold',(0,.65,-.15),(.27,.045,.06));s.save()
    s=Scene('winged_beast');s.part('Body','sphere','wing',(0,.12,0),(.34,.32,.55));s.part('Head','sphere','wing',(0,.22,-.29),(.28,.28,.28))
    s.part('Beak','prism','gold',(0,.19,-.49),(.2,.16,.25))
    for sign in [-1,1]:
        s.part('Wing'+str(sign),'prism','wing',(sign*.43,.16,.05),(.72,.08,.65),wing=sign)
        s.part('Eye'+str(sign),'sphere','dark',(sign*.12,.28,-.36),(.05,.05,.05))
        s.part('Claw'+str(sign),'box','gold',(sign*.12,-.09,.02),(.06,.18,.08))
    s.part('Tail','prism','dark',(0,.14,.46),(.3,.06,.3));s.save()
    s=Scene('scout');s.humanoid('scout')
    s.part('Hood','cylinder','scout',(0,.86,.03),(.08,.25,.2));s.part('Feather','prism','white',(.1,1.02,.04),(.08,.28,.08))
    s.part('Telescope','box','gold',(.2,.64,-.19),(.1,.1,.35));s.part('Dagger','prism','iron',(-.24,.28,-.14),(.06,.32,.07));s.save()
    s=Scene('saboteur');s.humanoid('saboteur')
    s.part('Cap','cylinder','leather',(0,.86,0),(.19,.12,.2));s.part('Goggles','box','gold',(0,.8,-.15),(.28,.08,.045))
    s.part('Pack','box','leather',(0,.44,.25),(.34,.39,.2));s.part('Bomb','sphere','dark',(.28,.3,-.14),(.3,.3,.3))
    s.part('Fuse','box','gold',(.28,.51,-.14),(.035,.14,.035));s.part('Wrench','box','iron',(-.28,.35,-.1),(.06,.43,.08));s.save()
ICONS={
'rat_swarm':('rat','<ellipse cx="31" cy="38" rx="20" ry="12"/><path d="m13 37-8 7 11 2M48 40q15 8 10-13" fill="none" stroke-width="4"/><circle cx="19" cy="26" r="9"/><circle cx="14" cy="37" r="2" fill="#eee5cf"/>'),
'shield_guardian':('guardian','<path d="M15 12 32 7 49 12v24L32 57 15 36Z"/><path d="M32 16v28M23 29h18" fill="none" stroke="#eee5cf" stroke-width="5"/>'),
'blood_mage':('mage','<path d="m32 5 17 23-7 23H22l-7-23Z"/><path d="M32 17c-4 7-9 12-9 17a9 9 0 0 0 18 0c0-5-5-10-9-17Z" fill="#eee5cf"/>'),
'winged_beast':('wing','<path d="m32 27-7-9L3 9l7 25 14 4 8 18 8-18 14-4 7-25-22 9Z"/><path d="m27 25 5-12 5 12" fill="#eee5cf"/>'),
'scout':('scout','<path d="m32 6-17 25 2 24h30l2-24Z"/><path d="m22 34 21-10 4 8-22 10Z" fill="#eee5cf"/><path d="m38 12 11-9-3 19Z"/>'),
'saboteur':('saboteur','<circle cx="30" cy="39" r="19"/><path d="m25 18 10-1 1 8-10 1ZM31 17q0-13 12-10"/><path d="m45 3 2 8 7-4-5 7 8 2-8 2" fill="none" stroke-width="3"/>')}
def icons():
    for key,(c,body) in ICONS.items():
        (ROOT/'assets/sprites/enemies'/f'{key}.svg').write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><g fill="{COLORS[c]}" stroke="{COLORS[c]}" stroke-linejoin="round">{body}</g></svg>\n',encoding='utf-8')
if __name__=='__main__':models();icons()
