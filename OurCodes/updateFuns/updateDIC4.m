function [CURINFOR, UPDATA_DIC] = updateDIC4(fpre_gt,CURINFOR,param,PRE_DIC,PREINFPOR)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 根据外观模型的结果，自适应的更新字典
% 衡量的是前后帧之间的相对变化
% 
% fpre_gt/fcur_gt 分别表示前一帧与当前帧的伪GT
%
% CURINFOR 当前帧预测得到的一些结果
% spsal/psal/imsal/imgt/fea/ORlabels/spinfor
%
% param
% THL 高低阈值
%
% PRE_DIC
% PRE_DIC.D0 = D0;
% PRE_DIC.DB = DB;
% PRE_DIC.beta = beta; 弱分类器权重及对应系数
% PRE_DIC.model = model; 
%     model{t,1}.dic         dic.p     dic.n
%     model{t,1}.mapping     mapping.p mapping.n
%
% V1: 2016.08.01  9:07AM
% V2: 2016.08.18 19:23PM
% V3: 2016.08.25 19:38pm
% 于updateDIC基础上进行修改
% 
% V4: 2016.08.30 19:59PM
% 使用PCA基向量做字典，MultiFeaBoostingTrainNew0
%
% V5：2016.08.31 9：51PM
% 对gt引入膨胀运算（形态学处理）;转移至apperanceModel中
%
% V6: 2016.08.31 22:54PM
% 全更
%
% V7:2016.09.01 13:35PM 
% 引入前一帧的限制条件
% PREINFPOR.objectnum 
% PREINFPOR.objectarea 
% PREINFPOR.objectcenter 
% 同时返回当前帧的物体大致范围信息（objectnum,objectarea,objectcenter）
% 全更
% 
% copyright by xiaofei zhou
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 1.initialization &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
% 获取阈值
% th = param.THL(1);
% tl = param.THL(2);
ee = param.ee;
fcur_gt = CURINFOR.imgt;

% % revised in 2016.08.31 9:50AM 引入膨胀运算 --------
% BB = strel('disk',4);
% % fcur_gt = imdilate(fcur_gt, BB);
%  fcur_gt = imclose(fcur_gt, BB);
% % -------------------------------------------------
% location
[tmpPREINFPOR, gtinfor] = getGTINFORnew(fcur_gt, ee, PREINFPOR);
SPSCALENUM = length(CURINFOR.ORLabels);

% 各区域同OR的关系
ORLabels = computeORLabel(gtinfor.LCEND, gtinfor.objIndex, CURINFOR.spinfor,param);% sampleNum*3/cell

% 原始字典
CURD0 = computeD0(SPSCALENUM,CURINFOR.spinfor,ORLabels,CURINFOR.fea);


%% 2. 变化率：相对于前一帧的变化率，自适应更新
fpre_gt = double(fpre_gt>=0.5);
fcur_gt = double(fcur_gt>=0.5);
RATIO = 1 - sum(sum(fpre_gt.*fcur_gt))/sum(sum(fpre_gt));% y_(t-1)  y_t
% beta = param.beta;
% betaP = beta(1);
% betaN = beta(2);

%% 2.1 计算区域显著性值 ---------------------
spSal = computeGTinfor(fcur_gt,CURINFOR.spinfor);

% %% 2.2 Boosting 训练  ----------------------
% [UPDATA_DIC.D0, UPDATA_DIC.beta, UPDATA_DIC.model, tmodel] = ...
%     MultiFeaBoostingTrain(UPDATA_DIC.DB,UPDATA_DIC.D0,ORLabels,spSal,param);

%% 2.2 获取DB，更新D0 ----------------------
    fprintf('\nFULLUPDATe = %d',RATIO)
    % 利用cur_or_infor.D0 进行PCA得到DB
    DB = D02DBNew(CURD0,param);
    UPDATA_DIC.DB = DB; 
    UPDATA_DIC.D0 = CURD0;
    clear CURD0 DB 
%     [UPDATA_DIC.D0, UPDATA_DIC.beta, UPDATA_DIC.model, tmodel] = ...
%        MultiFeaBoostingTrain(UPDATA_DIC.DB,UPDATA_DIC.D0,ORLabels,spSal,param);
   
   [UPDATA_DIC.D0, UPDATA_DIC.beta, UPDATA_DIC.model, tmodel] = ...
       MultiFeaBoostingTrainNew0(UPDATA_DIC.DB,UPDATA_DIC.D0,ORLabels,spSal,param);

   
   % 返回当前帧的物体的位置信息 2016.09.01 16:11PM
CURINFOR.objectnum = tmpPREINFPOR.objectnum;
CURINFOR.objectarea = tmpPREINFPOR.objectarea;
CURINFOR.objectcenter = tmpPREINFPOR.objectcenter;
CURINFOR.objectlocation = tmpPREINFPOR.objectlocation;

%% clear
clear fpre_gt fcur_gt THl PRE_DIC
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%0 集中样本，将 pre & cur 的D0进行合并
function result = mergePreCurD0(CURD0,PRED0)
    result.P.colorHist_rgb = [CURD0.P.colorHist_rgb;PRED0.P.colorHist_rgb];
    result.P.colorHist_lab = [CURD0.P.colorHist_lab;PRED0.P.colorHist_lab]; 
    result.P.colorHist_hsv = [CURD0.P.colorHist_hsv;PRED0.P.colorHist_hsv];
    result.P.lbpHist       = [CURD0.P.lbpHist;      PRED0.P.lbpHist];    
    result.P.hogHist       = [CURD0.P.hogHist;      PRED0.P.hogHist];  
    result.P.regionCov     = [CURD0.P.regionCov;    PRED0.P.regionCov];    
    result.P.geoDist       = [CURD0.P.geoDist;      PRED0.P.geoDist];     
    result.P.flowHist      = [CURD0.P.flowHist;     PRED0.P.flowHist];      
    
    result.N.colorHist_rgb = [CURD0.N.colorHist_rgb;PRED0.N.colorHist_rgb];
    result.N.colorHist_lab = [CURD0.N.colorHist_lab;PRED0.N.colorHist_lab]; 
    result.N.colorHist_hsv = [CURD0.N.colorHist_hsv;PRED0.N.colorHist_hsv];
    result.N.lbpHist       = [CURD0.N.lbpHist;      PRED0.N.lbpHist];    
    result.N.hogHist       = [CURD0.N.hogHist;      PRED0.N.hogHist];  
    result.N.regionCov     = [CURD0.N.regionCov;    PRED0.N.regionCov];    
    result.N.geoDist       = [CURD0.N.geoDist;      PRED0.N.geoDist];     
    result.N.flowHist      = [CURD0.N.flowHist;     PRED0.N.flowHist]; 
    
    clear CURD0 PRED0
end

%1 计算D0(所有cell下集中进行测试)
function D0 = computeD0(ScaleNums,spinfor,ORLabels,fea)
% fea 全尺寸， sampleNum = tmpSP.spNum
    D0.P = struct;D0.N = struct;% sampleNum*feaDim
    DP_colorHist_rgb = []; DN_colorHist_rgb = [];
    DP_colorHist_lab = []; DN_colorHist_lab = [];
    DP_colorHist_hsv = []; DN_colorHist_hsv = [];
    DP_lbpHist       = []; DN_lbpHist       = [];
    DP_hogHist       = []; DN_hogHist       = [];
    DP_regionCov     = []; DN_regionCov     = [];
    DP_geoDist       = []; DN_geoDist       = [];
    DP_flowHist      = []; DN_flowHist      = [];
    
    for ss=1:ScaleNums
        tmpSP = spinfor{ss,1};
        tmpORlabel = ORLabels{ss,1};% spNum*3
        ISORlabel = tmpORlabel(:,1);
%         index_out_OR = find(ISORlabel~=1);
        ISOBJlabel = tmpORlabel(:,3);
        PNlabel = ISORlabel.*ISOBJlabel;% (1,1) P 
%         PNlabel(index_out_OR,:) = [];
        indexP = find(PNlabel==1);
%         indexN = find(PNlabel==0);

        % revised in 2016.08.30 22:32PM  ----------------------------------
        % 全尺寸状态， 需间接统计负样本的标号
        indexN = [];% (1,0) N
        for sp=1:tmpSP.spNum
            if ISORlabel(sp)==1 && ISOBJlabel(sp)==0
                indexN = [indexN;sp];
            end
        end
        % -----------------------------------------------------------------
        
        DP_colorHist_rgb = [DP_colorHist_rgb;fea{ss,1}.colorHist_rgb(indexP,:)];
        DP_colorHist_lab = [DP_colorHist_lab;fea{ss,1}.colorHist_lab(indexP,:)];
        DP_colorHist_hsv = [DP_colorHist_hsv;fea{ss,1}.colorHist_hsv(indexP,:)];  
        DP_lbpHist       = [DP_lbpHist;      fea{ss,1}.lbpHist(indexP,:)];
        DP_hogHist       = [DP_hogHist;      fea{ss,1}.hogHist(indexP,:)];
        DP_regionCov     = [DP_regionCov;    fea{ss,1}.regionCov(indexP,:)];
        DP_geoDist       = [DP_geoDist;      fea{ss,1}.geoDist(indexP,:)];
        DP_flowHist      = [DP_flowHist;     fea{ss,1}.flowHist(indexP,:)];
        
        DN_colorHist_rgb = [DN_colorHist_rgb;fea{ss,1}.colorHist_rgb(indexN,:)];
        DN_colorHist_lab = [DN_colorHist_lab;fea{ss,1}.colorHist_lab(indexN,:)];
        DN_colorHist_hsv = [DN_colorHist_hsv;fea{ss,1}.colorHist_hsv(indexN,:)];  
        DN_lbpHist       = [DN_lbpHist;      fea{ss,1}.lbpHist(indexN,:)];
        DN_hogHist       = [DN_hogHist;      fea{ss,1}.hogHist(indexN,:)];
        DN_regionCov     = [DN_regionCov;    fea{ss,1}.regionCov(indexN,:)];
        DN_geoDist       = [DN_geoDist;      fea{ss,1}.geoDist(indexN,:)];
        DN_flowHist      = [DN_flowHist;     fea{ss,1}.flowHist(indexN,:)];    
        
    end
    D0.P.colorHist_rgb = DP_colorHist_rgb; 
    D0.P.colorHist_lab = DP_colorHist_lab; 
    D0.P.colorHist_hsv = DP_colorHist_hsv; 
    D0.P.lbpHist       = DP_lbpHist;
    D0.P.hogHist       = DP_hogHist;
    D0.P.regionCov     = DP_regionCov;
    D0.P.geoDist       = DP_geoDist;
    D0.P.flowHist      = DP_flowHist;
    
    D0.N.colorHist_rgb = DN_colorHist_rgb; 
    D0.N.colorHist_lab = DN_colorHist_lab; 
    D0.N.colorHist_hsv = DN_colorHist_hsv; 
    D0.N.lbpHist       = DN_lbpHist;
    D0.N.hogHist       = DN_hogHist;
    D0.N.regionCov     = DN_regionCov;
    D0.N.geoDist       = DN_geoDist;
    D0.N.flowHist      = DN_flowHist;

clear ScaleNums spinfor ORLabels fea
clear DP_colorHist_rgb DP_colorHist_lab DP_colorHist_hsv DP_lbpHist DP_hogHist DP_regionCov DP_geoDist DP_flowHist
clear DN_colorHist_rgb DN_colorHist_lab DN_colorHist_hsv DN_lbpHist DN_hogHist DN_regionCov DN_geoDist DN_flowHist

end


%2 计算OR区域标签： OR内外，边界，前背景 
function ORLabels = computeORLabel(LCEND, objIndex, spinfor,param)
% lend = [x1,y1,x2,y2];
% objectIndex GT标签
% 
ORTHS = param.ORTHS;
OR_th = ORTHS(1);
OR_BORDER_th = ORTHS(2);
OR_OB_th = ORTHS(3);

SPSCALENUM = length(spinfor);
ORLabels = cell(SPSCALENUM,1);

[height,width,dims] = size(spinfor{1,1}.idxcurrImage);
ORI = zeros(height,width);
ORI(LCEND(2):LCEND(4),LCEND(1):LCEND(3))=1;
ORIndex = find(ORI(:)==1);

for ss=1:SPSCALENUM % 每个尺度下
    tmpSP = spinfor{ss,1};
    
    LABEL = [];ISOR=[];ISOBJ=[];ISBORDER = [];
    for sp=1:tmpSP.spNum % 各区域
        TMP = find(tmpSP.idxcurrImage==sp);
        
        % 1. 首先判断是否在OR区域内 1/0
        indSP_OR = ismember(TMP, ORIndex);
        ratio_OR = sum(indSP_OR)/length(indSP_OR);
        
        % revised in 2016.08.29 8:07AM ------------------------------------
        if ratio_OR==0
            ISOR = [ISOR;0];
            ISBORDER = [ISBORDER;0];
        else
            ISOR = [ISOR;1];% 属于OR区域
            
            if ratio_OR>0 && ratio_OR<1
                ISBORDER = [ISBORDER;1];% 边界超像素区域
            end
            
            if ratio_OR==1
                ISBORDER = [ISBORDER;0];
            end
        end
        % -----------------------------------------------------------------
%         if  ratio_OR< OR_th % 位于OR外部
%             ISOR = [ISOR;0];
%             ISBORDER = [ISBORDER;0];
%         else
%             ISOR = [ISOR;1];
%             % 2. 判定OR区域边界超像素 <1 OR边界超像素
%             if ratio_OR<OR_BORDER_th
%                 ISBORDER = [ISBORDER;1];% 边界超像素区域
%             else
%                 ISBORDER = [ISBORDER;0];
%             end        
%         end
        
        %3. 再判断是否在Object中 1/0
        if isempty(objIndex)
        ISOBJ = [ISOBJ;100];  
        else
        indSP_GT = ismember(TMP,objIndex);
        ratio_GT = sum(indSP_GT)/length(indSP_GT);
        if  ratio_GT < OR_OB_th
            ISOBJ = [ISOBJ;0];% NEGTIVE
        else
            ISOBJ = [ISOBJ;1]; % POSITIVE
        end;            
        end

        
    end
    LABEL = [ISOR,ISBORDER,ISOBJ];
    ORLabels{ss,1} = LABEL;
    clear tmpSP
end

clear LCEND objIndex spinfor param

end


% 3 获取LCEND & OBJECTINDEX
function [tmpPREINFPOR, gtinfor] = getGTINFORnew(fcur_gt, ee, PREINFPOR)
% 确定operation region: LCEND(x1,y1,x2,y2), lefttop & rightbottom
% 20160802  12:37PM
% 2016.09.01 13:42PM 引入前一帧的限制条件
% PREINFPOR.objectnum 
% PREINFPOR.objectarea 
% PREINFPOR.objectcenter 
% PREINFPOR.objectlocation
% 
[height,width] = size(fcur_gt);
showimgs = zeros(height,width,3);
showimgs(:,:,1) = fcur_gt;
showimgs(:,:,2) = fcur_gt;
showimgs(:,:,3) = fcur_gt;
objIndex = find(fcur_gt(:)==1);
[sy,sx] = ind2sub([height,width],objIndex);

[boxself,lcSelf] = boundingboxNew3( fcur_gt, showimgs, PREINFPOR);% old version boundingboxNew
objectNum = size(lcSelf,1);
% [boxself,lcSelf] = boundingboxNew(fcur_gt,showimgs);

% --- revised in 2016.08.21 9:29AM ----------------------------------------
% 去除单物体情形 
if size(lcSelf,1)>1
lc1 = min(lcSelf(:,1:2));
lc2 = max(lcSelf(:,3:4));
LC = [lc1,lc2];    
else
LC = lcSelf;
end
% -------------------------------------------------------------------------
dw = LC(3) - LC(1)+1;
dh = LC(4) - LC(2)+1;

centerY = LC(2) + round(dh/2);
centerX = LC(1) + round(dw/2);

extend_length_h = round(ee*dh/2);eh = round(dh/2) + extend_length_h;
extend_length_w = round(ee*dw/2);ew = round(dw/2) + extend_length_w;

x1New = centerX - ew;
y1New = centerY - eh;
if x1New<3
    x1New = 3;  
end
if y1New<3
    y1New = 3;
end

x2New = centerX + ew;
y2New = centerY + eh;
if x2New>width
    x2New = width-3;  
end
if y2New>height
    y2New = height-3;
end
LC1 = [x1New,y1New,x2New,y2New];
[BoxEnd,LCEND]=draw_rect(showimgs,LC1(1),LC1(2),LC1(3),LC1(4));
objectArea   = [LCEND(4)-LCEND(2) + 1, LCEND(3) - LCEND(1) + 1];
objectCenter = [centerY,centerX];

figure,
subplot(1,2,1),imshow(boxself,[])
subplot(1,2,2),imshow(BoxEnd,[])

clear BoxEnd boxself
gtinfor.objIndex = objIndex;% 物体像素为1，背景为0
gtinfor.lcSelf = lcSelf;% 物体的boundingbox的位置坐标
gtinfor.sy = sy; % 物体的像素的位置坐标
gtinfor.sx = sx;
gtinfor.LCEND = LCEND;% 最终物体的boundingbox的左上角、右下角坐标


tmpPREINFPOR.objectnum = objectNum;
tmpPREINFPOR.objectarea = objectArea;
tmpPREINFPOR.objectcenter = objectCenter;
tmpPREINFPOR.objectlocation = lcSelf;


clear objIdex lcSelf LCEND showimg PREINFPOR
end

% 4 获取LCEND,用于gtinfor中
function [result,lc]=draw_rect(RGB_img,x1,y1,x2,y2)


rgb = [255 0 0];                                 % 杈规棰滆壊
                          
x1=floor(x1);
x2=floor(x2);
y1=floor(y1);
y2=floor(y2);

% if x1<3||x2<3||y1<3||y2<3
%     x1=3;
%     x2=3;
%     y1=3;
%     y2=3;
% end

if x1<3
    x1=3;
end
if x2<3
    x2=3;
end
if y1<3
    y1=3;
end
if y2<3
   y2=3;
end
 

result = RGB_img;
if size(result,3) == 3
    for k=1:3
          %鐢昏竟妗嗛『搴忎负锛氫笂鍙充笅宸︾殑鍘熷垯
%             result(x1,y1:y1+x2,k)=rgb(1,k);
%             result(x1:x1+y2,y1+x2,k) = rgb(1,k);
%             result(x1+y2,y1:y1+x2,k) = rgb(1,k);  
%             result(x1:x1+y2,y1,k) = rgb(1,k);  
          
            result(y1-1:y1+1,x1:x2,k)=rgb(1,k);
            result(y1:y2,x2-1:x2+1,k) = rgb(1,k);
            result(y2-1:y2+1,x1:x2,k) = rgb(1,k);  
            result(y1:y2,x1-1:x1+1,k) = rgb(1,k);          
       
    end
end
    


lc = [x1,y1,x2,y2];


end

% 5 计算由GT得到的各区域sal与label,用于boosting训练
function spSal = computeGTinfor(imGT,spinfor)
% result = computeGTinfor(imGT,spinfor,objth)
imGT = double(imGT>=0.5);
% GTinfor.spSal = cell(length(spinfor),1);
% GTinfor.spLabel = cell(length(spinfor),1);
spSal = cell(length(spinfor),1);
for ss=1:length(spinfor)
    tmpSP = spinfor{ss,1};
    tmpSPsal = zeros(tmpSP.spNum,1);
%     tmpSPlabel = zeros(tmpSP.spNum,1);
    for sp=1:tmpSP.spNum
        tmpSPsal(sp,1) = mean(imGT(tmpSP.pixelList{sp,1}));     
%         if tmpSPsal(sp,1)>=objth
%             tmpSPlabel(sp,1) = 1;% 前景
%         else
%             tmpSPlabel(sp,1) = 0;% 背景
%         end
    end
    spSal{ss,1} = tmpSPsal;
%     GTinfor.spSal{ss,1} = tmpSPsal;
%     GTinfor.spLabel{ss,1} = tmpSPlabel;
    clear tmpSPsal tmpSP tmpSPlabel
end

clear imGT spinfor objth
end
