from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops
import sys
S=1200; R=150
src=Image.open("artwork-no-title.png").convert("RGBA")
bgfill=src.resize((S,S),Image.LANCZOS).filter(ImageFilter.GaussianBlur(30))
inner_art=src.resize((1032,1032),Image.LANCZOS)
art=bgfill.copy()
# feather the pasted artwork's edges so there's no visible seam
fm=Image.new("L",(1032,1032),0); ImageDraw.Draw(fm).rectangle([50,50,981,981],fill=255)
fm=fm.filter(ImageFilter.GaussianBlur(28))
art.paste(inner_art,(84,72),fm)
def lerp(a,b,t): return tuple(int(a[i]+(b[i]-a[i])*t) for i in range(len(a)))
def rmask(box,r):
    m=Image.new("L",(S,S),0); ImageDraw.Draw(m).rounded_rectangle(box,radius=r,fill=255); return m
img=Image.new("RGBA",(S,S),(0,0,0,0))
img.paste(art,(0,0),rmask([0,0,S-1,S-1],R))
# darken the bottom a touch so the title pops
fade=Image.new("L",(S,S),0); fd=ImageDraw.Draw(fade)
for y in range(780,S): fd.line([(0,y),(S,y)],fill=int(120*(y-780)/(S-780)))
img=Image.composite(Image.new("RGBA",(S,S),(4,6,12,255)),img,fade.point(lambda v:v)).copy() if False else Image.alpha_composite(img, Image.composite(Image.new("RGBA",(S,S),(4,6,12,255)),Image.new("RGBA",(S,S),(0,0,0,0)),ImageChops.multiply(fade,rmask([0,0,S-1,S-1],R))))
# gold beveled rim + inner shadow
RIM=24
rim=Image.new("RGBA",(S,S),(0,0,0,0)); rd=ImageDraw.Draw(rim)
for i in range(RIM):
    t=i/(RIM-1)
    rd.rounded_rectangle([i,i,S-1-i,S-1-i],radius=R-i,outline=lerp((110,74,18,255),(255,226,140,255),__import__('math').sin(t*3.14159)),width=1)
inner=rmask([RIM,RIM,S-1-RIM,S-1-RIM],R-RIM)
rim.putalpha(ImageChops.multiply(rim.getchannel("A"),ImageChops.subtract(rmask([0,0,S-1,S-1],R),inner)))
img=Image.alpha_composite(img,rim)
sh=Image.new("RGBA",(S,S),(0,0,0,0)); ImageDraw.Draw(sh).rounded_rectangle([RIM,RIM,S-1-RIM,S-1-RIM],radius=R-RIM,outline=(0,0,0,210),width=26)
sh=sh.filter(ImageFilter.GaussianBlur(18)); sh.putalpha(ImageChops.multiply(sh.getchannel("A"),inner))
img=Image.alpha_composite(img,sh)
# title: Cinzel (carved fantasy capitals) with an embossed metal look
CINZEL="Cinzel.ttf"  # download Cinzel from fonts.google.com/specimen/Cinzel
def cfont(size, weight):
    f=ImageFont.truetype(CINZEL,size); f.set_variation_by_name(weight); return f
def layer(t,size,weight,y,grad,track=0):
    f=cfont(size,weight); m=Image.new("L",(S,S),0); md=ImageDraw.Draw(m)
    w=sum(md.textlength(c,font=f) for c in t)+track*(len(t)-1); x=(S-w)/2
    for c in t: md.text((x,y),c,font=f,fill=255); x+=md.textlength(c,font=f)+track
    bb=m.getbbox(); g=Image.new("RGBA",(S,S)); gd=ImageDraw.Draw(g)
    for yy in range(S):
        tt=min(max((yy-bb[1])/max(bb[3]-bb[1],1),0),1)
        # three-stop metal gradient: bright top, darker middle band, lighter bottom lip
        if tt<0.55: c=lerp(grad[0],grad[1],tt/0.55)
        else: c=lerp(grad[1],grad[2],(tt-0.55)/0.45)
        gd.line([(0,yy),(S,yy)],fill=c)
    clear=Image.new("RGBA",(S,S),(0,0,0,0))
    shadow=Image.composite(Image.new("RGBA",(S,S),(0,0,0,240)),clear,m).filter(ImageFilter.GaussianBlur(12))
    outline=Image.composite(Image.new("RGBA",(S,S),(18,12,4,255)),clear,m.filter(ImageFilter.MaxFilter(9)))
    fill=Image.composite(g,clear,m)
    # bevel: bright top edges, dark bottom edges
    top=ImageChops.subtract(m,ImageChops.offset(m,0,4)).filter(ImageFilter.GaussianBlur(1))
    bot=ImageChops.subtract(m,ImageChops.offset(m,0,-4)).filter(ImageFilter.GaussianBlur(1))
    hi=Image.composite(Image.new("RGBA",(S,S),(255,255,255,200)),clear,top)
    lo=Image.composite(Image.new("RGBA",(S,S),(40,24,6,170)),clear,bot)
    return [ImageChops.offset(shadow,0,12), outline, fill, lo, hi]
SILVER=((255,255,255,255),(176,186,204,255),(230,236,246,255))
GOLD=((255,240,170,255),(198,128,26,255),(255,206,96,255))
for L_ in layer("YaHT",230,"Black",770,SILVER,track=6) + layer("FOREVER",88,"Bold",1030,GOLD,track=22):
    img=Image.alpha_composite(img,L_)
img.resize((400,400),Image.LANCZOS).save("YaHT-Forever-icon-400.png")
img.resize((1024,1024),Image.LANCZOS).save("YaHT-Forever-icon-1024.png")
print("ok")
