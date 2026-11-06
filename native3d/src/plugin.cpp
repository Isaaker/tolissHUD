// XPHUD Native 3D hardware prototype. Copyright (c) 2026 Control_TWR.
// Optional physical-looking hardware only; Lua symbology remains a separate 2D overlay.
#include <XPLMDataAccess.h>
#include <XPLMInstance.h>
#include <XPLMMenus.h>
#include <XPLMPlanes.h>
#include <XPLMPlugin.h>
#include <XPLMProcessing.h>
#include <XPLMScenery.h>
#include <XPLMUtilities.h>
#include <algorithm>
#include <cctype>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <string>
#if !defined(XPLM300)
#error "XPHUD Native 3D requires XPLM300 or newer."
#endif
namespace {
const char *kObj="Resources/plugins/XPHUD_Native3D/objects/xphud_native_combiner.obj";
const char *kMarker="AirbusFBW/APHDG_Capt";
struct Cal { double x=-0.58,y=1.15,z=-7.0,pitch=0,heading=0,roll=0; bool enabled=true; } cal;
struct Refs { XPLMDataRef x=nullptr,y=nullptr,z=nullptr,psi=nullptr,theta=nullptr,phi=nullptr; } refs;
XPLMDataRef marker=nullptr; XPLMObjectRef object=nullptr; XPLMInstanceRef instance=nullptr;
XPLMMenuID menu=nullptr; bool running=false,tried=false,toliss=false; float retry=0,aircraftTimer=1,step=0.01f;
int tokens[25]{}; constexpr float angleStep=0.5f;
double limit(double v,double lo,double hi){return std::max(lo,std::min(hi,v));}
void log(const std::string&s){XPLMDebugString(("XPHUD Native3D: "+s+"\n").c_str());}
std::string configPath(){char root[1024]{};XPLMGetSystemPath(root);std::string p(root);if(!p.empty()&&p.back()!='/'&&p.back()!='\\')p+='/';return p+"Output/preferences/xphud_native3d.cfg";}
void loadConfig(){std::ifstream in(configPath());std::string l;while(std::getline(in,l)){auto n=l.find('=');if(n==std::string::npos)continue;auto k=l.substr(0,n),v=l.substr(n+1);char*e=nullptr;double d=std::strtod(v.c_str(),&e);if(e==v.c_str()||*e||!std::isfinite(d))continue;if(k=="x")cal.x=limit(d,-3,3);else if(k=="y")cal.y=limit(d,-1,4);else if(k=="z")cal.z=limit(d,-15,5);else if(k=="pitch")cal.pitch=limit(d,-30,30);else if(k=="heading")cal.heading=limit(d,-30,30);else if(k=="roll")cal.roll=limit(d,-30,30);else if(k=="enabled")cal.enabled=d!=0;}}
void saveConfig(){std::ofstream o(configPath(),std::ios::trunc);if(!o){log("Cannot save calibration preferences.");return;}o.setf(std::ios::fixed);o.precision(4);o<<"x="<<cal.x<<"\ny="<<cal.y<<"\nz="<<cal.z<<"\npitch="<<cal.pitch<<"\nheading="<<cal.heading<<"\nroll="<<cal.roll<<"\nenabled="<<(cal.enabled?1:0)<<"\n";log("Calibration saved.");}
void printCal(){char b[220]{};std::snprintf(b,sizeof(b),"XYZ %.3f %.3f %.3f m / P-H-R %.2f %.2f %.2f deg / step %.3f m",cal.x,cal.y,cal.z,cal.pitch,cal.heading,cal.roll,step);log(b);}
void destroy(){if(instance){XPLMDestroyInstance(instance);instance=nullptr;}}
bool findRefs(){if(refs.x&&refs.y&&refs.z&&refs.psi&&refs.theta&&refs.phi)return true;refs.x=XPLMFindDataRef("sim/flightmodel/position/local_x");refs.y=XPLMFindDataRef("sim/flightmodel/position/local_y");refs.z=XPLMFindDataRef("sim/flightmodel/position/local_z");refs.psi=XPLMFindDataRef("sim/flightmodel/position/psi");refs.theta=XPLMFindDataRef("sim/flightmodel/position/theta");refs.phi=XPLMFindDataRef("sim/flightmodel/position/phi");return refs.x&&refs.y&&refs.z&&refs.psi&&refs.theta&&refs.phi;}
bool isToLiss(float dt){aircraftTimer+=std::max(0.0f,dt);if(aircraftTimer>=1){aircraftTimer=0;char file[256]{},path[1024]{};XPLMGetNthAircraftModel(0,file,path);std::string id=std::string(file)+" "+path;std::transform(id.begin(),id.end(),id.begin(),[](unsigned char c){return static_cast<char>(std::tolower(c));});marker=XPLMFindDataRef(kMarker);toliss=id.find("toliss")!=std::string::npos&&marker;}return toliss;}
bool createInstance(){if(!object||instance)return instance!=nullptr;const char*none[]={nullptr};instance=XPLMCreateInstance(object,none);if(!instance)log("XPLMCreateInstance failed; retrying.");return instance!=nullptr;}
void loadObject(){if(object||tried)return;tried=true;object=XPLMLoadObject(kObj);if(!object){log(std::string("Unable to load OBJ: ")+kObj);return;}if(!createInstance()){XPLMUnloadObject(object);object=nullptr;}}
void nudge(int a){switch(a){case 1:cal.x-=step;break;case 2:cal.x+=step;break;case 3:cal.y-=step;break;case 4:cal.y+=step;break;case 5:cal.z-=step;break;case 6:cal.z+=step;break;case 7:cal.pitch-=angleStep;break;case 8:cal.pitch+=angleStep;break;case 9:cal.heading-=angleStep;break;case 10:cal.heading+=angleStep;break;case 11:cal.roll-=angleStep;break;case 12:cal.roll+=angleStep;break;}cal.x=limit(cal.x,-3,3);cal.y=limit(cal.y,-1,4);cal.z=limit(cal.z,-15,5);cal.pitch=limit(cal.pitch,-30,30);cal.heading=limit(cal.heading,-30,30);cal.roll=limit(cal.roll,-30,30);printCal();}
void handler(void*,void*ref){int a=-1;for(int i=0;i<25;i++)if(ref==&tokens[i]){a=i;break;}if(a<0)return;if(a==20){cal.enabled=!cal.enabled;if(!cal.enabled)destroy();log(cal.enabled?"Hardware enabled":"Hardware disabled");}else if(a==21){step=step<0.02f?0.05f:0.01f;log(step<0.02f?"Position step 1 cm":"Position step 5 cm");}else if(a==22)saveConfig();else if(a==23){cal=Cal{};printCal();}else if(a==24)printCal();else nudge(a);}
void add(const char*s,int a){XPLMAppendMenuItem(menu,s,&tokens[a],1);}
void createMenu(){auto parent=XPLMFindPluginsMenu();int index=XPLMAppendMenuItem(parent,"XPHUD Native 3D",nullptr,1);menu=XPLMCreateMenu("XPHUD Native 3D",parent,index,handler,nullptr);if(!menu){log("Could not create calibration menu.");return;}add("Toggle hardware",20);add("Toggle position step (1 / 5 cm)",21);add("X left",1);add("X right",2);add("Y down",3);add("Y up",4);add("Z forward",5);add("Z aft",6);add("Pitch -0.5",7);add("Pitch +0.5",8);add("Yaw -0.5",9);add("Yaw +0.5",10);add("Roll -0.5",11);add("Roll +0.5",12);add("Print calibration to Log.txt",24);add("Save calibration",22);add("Reset calibration",23);}
// Laminar Research aircraft-to-world Euler transform; aircraft axes +X right, +Y up, +Z aft.
void toWorld(double x,double y,double z,double ph,double th,double ps,double&X,double&Y,double&Z){constexpr double pi=3.14159265358979323846;double p=ph*pi/180,t=th*pi/180,h=ps*pi/180;double xp=x*std::cos(p)+y*std::sin(p),yp=y*std::cos(p)-x*std::sin(p),zp=z;double xt=xp,yt=yp*std::cos(t)-zp*std::sin(t),zt=zp*std::cos(t)+yp*std::sin(t);X=xt*std::cos(h)-zt*std::sin(h)+XPLMGetDataf(refs.x);Y=yt+XPLMGetDataf(refs.y);Z=zt*std::cos(h)+xt*std::sin(h)+XPLMGetDataf(refs.z);}
float flightLoop(float dt,float,int,void*){if(!running)return 1;if(!isToLiss(dt)||!cal.enabled){destroy();return 1;}if(!findRefs()){destroy();return 1;}if(!object&&!tried){retry+=dt;if(retry>=0.1f)loadObject();}if(!object&&tried){retry+=dt;if(retry>=5){retry=0;tried=false;}return 1;}if(object&&!instance&&!createInstance())return 1;if(!instance)return 1;double ph=XPLMGetDataf(refs.phi),th=XPLMGetDataf(refs.theta),ps=XPLMGetDataf(refs.psi),x,y,z;toWorld(cal.x,cal.y,cal.z,ph,th,ps,x,y,z);XPLMDrawInfo_t d{};d.structSize=sizeof(d);d.x=static_cast<float>(x);d.y=static_cast<float>(y);d.z=static_cast<float>(z);d.pitch=static_cast<float>(th+cal.pitch);d.heading=static_cast<float>(ps+cal.heading);d.roll=static_cast<float>(ph+cal.roll);const float empty[1]={0};XPLMInstanceSetPosition(instance,&d,empty);return -1;}
void stop(){XPLMUnregisterFlightLoopCallback(flightLoop,nullptr);destroy();if(object){XPLMUnloadObject(object);object=nullptr;}tried=false;running=false;}
}
PLUGIN_API int XPluginStart(char*n,char*s,char*d){std::snprintf(n,256,"%s","XPHUD Native 3D");std::snprintf(s,256,"%s","controltwr.xphud.native3d");std::snprintf(d,256,"%s","Experimental ToLiss A32X combiner hardware prototype.");loadConfig();createMenu();log("Loaded; experimental 3D hardware only. Lua remains a screen-space overlay.");return 1;}
PLUGIN_API void XPluginStop(void){stop();if(menu){XPLMDestroyMenu(menu);menu=nullptr;}}
PLUGIN_API int XPluginEnable(void){running=true;tried=false;retry=0;aircraftTimer=1;toliss=false;XPLMRegisterFlightLoopCallback(flightLoop,-1.0f,nullptr);return 1;}
PLUGIN_API void XPluginDisable(void){stop();}
PLUGIN_API void XPluginReceiveMessage(XPLMPluginID,int,void*){}
