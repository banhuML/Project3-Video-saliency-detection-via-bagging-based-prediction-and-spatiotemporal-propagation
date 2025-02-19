function [TPSPSAL,TPSPSALRegionSal] = spatialPropagationNew10_3(CURINFOR,IMSAL_TPSAL1,param,cur_image,GPsign)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 在时域传播的基础上进行空域传播
% CURINFOR
% fea/ORLabels/spinfor(mapsets，region_center_prediction)
% 
% spinfor{ss,1}.adjcMatrix;
% spinfor{ss,1}.colDistM 
% spinfor{ss,1}.clipVal 
% spinfor{ss,1}.idxcurrImage 
% spinfor{ss,1}.adjmat
% spinfor{ss,1}.pixelList 
% spinfor{ss,1}.area 
% spinfor{ss,1}.spNum 
% spinfor{ss,1}.bdIds 
% spinfor{ss,1}.posDistM 
% spinfor{ss,1}.region_center
% 
% FEA{ss,1}.colorHist_rgb 
% FEA{ss,1}.colorHist_lab 
% FEA{ss,1}.colorHist_hsv 
% FEA{ss,1}.lbpHist   
% FEA{ss,1}.hogHist  
% FEA{ss,1}.regionCov   
% FEA{ss,1}.geoDist    
% FEA{ss,1}.flowHist  
%
% TPSAL(全尺寸)
% 各尺度下各区域的显著性值
% 
% V1: 2016.10.14 20:01PM
% 仿照CVPR2016 GRAB思想进行传播优化
% 
% V2:2016.10.18 15:45PM
% 结合最新的 iterative propagation 进行修改
% 目前是背景传播+优化+前景传播；采用常规的图结构；无迭代
% 
% V3: 2016.10.19 16:18PM
% 引入迭代机制
% 
% V4： 2016.10.30 14：59PM
% object-biased + regression-based-{GMR --> SO --> GMR}
% 迭代的传播更新策略
% 采用常规图结构/最近邻
% 
% V5： 2016.11.02 21：03PM
% 新的空域传播方式
% 1) CURINFOR.fea  利用全部的特征，串接起来
%     fea{ss,1}.colorHist_rgb 
%     fea{ss,1}.colorHist_lab 
%     fea{ss,1}.colorHist_hsv 
%     fea{ss,1}.lbpHist     
%     fea{ss,1}.lbp_top_Hist 
%     fea{ss,1}.hogHist
%     fea{ss,1}.regionCov   
%     fea{ss,1}.geoDist    
%     fea{ss,1}.flowHist   
% 2) PCA           降维
% 
% [DB.P.colorHist_rgb_mappedA,DB.P.colorHist_rgb_mapping] = pca(D0.P.colorHist_rgb,no_dims);
% 3) 构建传播阵
% 
% V6: 2016.11.09 9:32am
% LOCAL-->GLOBAL + ITERATION
% 
% V7: 2016.11.10 10:34AM
% 2-hop  SP10_2
% 
% V8: 2016.11.10 12:35PM
% sink point  sp10_3
% 
% copyright by xiaofei zhou,shanghai university,shanghai,china
% zxforchid@163.com
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fprintf('\n this is spatial propagation process, wait a minute .........')
no_dims = param.no_dims;
bgRatio = param.bgRatio;
sp_iternum = param.sp_iternum;

[r,c] = size(IMSAL_TPSAL1);
% iterSal = IMSAL_TPSAL1;
ss = 1;% 仅仅一个尺度
IFmodel = '1';

%% A: 开讯迭代 &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
iterSal_Img = IMSAL_TPSAL1;
for iter = 1:sp_iternum
    fprintf('\n the %d iteration ......',iter)
    tmpFEA       = CURINFOR.fea{ss,1};
    tmpSPinfor   = CURINFOR.spinfor{ss,1};% 单尺度下的分割结果 
    pixelList    = tmpSPinfor.pixelList;
    regionCenter = tmpSPinfor.region_center;
    spNum        = tmpSPinfor.spNum;
    
%     if iter==1
%         iterSal_Img = IMSAL_TPSAL1;
%         iterSal  = computeRegionSal(IMSAL_TPSAL1,pixelList);
%         clear IMSAL_TPSAL1
%     end
   %% 1 根据融合后的时域传播图像，计算物体重心 &&&&&&&&&&&&&&&&&&&&&&&&
   fprintf('\n obtain object-center ...\n')
   iterSal           = computeRegionSal(iterSal_Img,pixelList);
%    [iterSal_Img, ~]  = CreateImageFromSPs(iterSal, pixelList, r, c, true);
   [rcenter,ccenter] = computeObjectCenter(iterSal_Img);% x-->row, y-->col  

    regionSal  = iterSal;
    regionDist = computeRegion2CenterDist(regionCenter,[rcenter,ccenter],[r,c]);
    init_compactness = computeCompactness(regionSal,regionDist);
%     init_compactness = sum(regionSal.*regionDist);
%     clear regionSal regionDist
    
    %% 2 形成大的特征矩阵 &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
    fprintf('\n compute features ...\n')
%     regionFea = [tmpFEA.colorHist_rgb,tmpFEA.colorHist_lab,tmpFEA.colorHist_hsv,tmpFEA.LM_texture,...
%         tmpFEA.lbp_top_Hist,tmpFEA.hogHist,tmpFEA.regionCov,tmpFEA.LM_textureHist,tmpFEA.geoDist,tmpFEA.flowHist];
    regionFea = [tmpFEA.colorHist_rgb,tmpFEA.colorHist_lab,tmpFEA.colorHist_hsv,...
               tmpFEA.lbp_top_Hist,tmpFEA.regionCov,tmpFEA.LM_textureHist,tmpFEA.flowHist];
    
    % regionFea_mappedA 为最终的区域特征
    [regionFea_mappedA,regionFea_mapping] = pca(regionFea,no_dims);
%     ZZ         = repmat(sqrt(sum(regionFea_mappedA.*regionFea_mappedA)),[tmpSPinfor.spNum,1]);% 特征全局归一化 2016.10.28 9:32AM
%     ZZ(ZZ==0)  = eps;
%     regionFea_mappedA  = regionFea_mappedA./ZZ;
%     FeaDist    = GetDistanceMatrix(regionFea_mappedA);    
    
    clear regionFea_mapping ZZ regionFea 
    
    %% 2.1 计算sink point &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
    fprintf('\n compute sink point for LP ...\n')
    IF_init = computeIF(regionDist,regionSal,spNum,bgRatio,IFmodel);
    clear regionSal regionDist
    
    %% 3 local propagation &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
    fprintf('\n local propagation ...\n')
    [LP_Img,LP_sal,LP_compactness,IF_LP_Infor] = ...
        localPropagation(regionFea_mappedA,iterSal,iterSal_Img,pixelList,...
                         init_compactness,tmpSPinfor,[r,c],IF_init);
    clear IF_init init_compactness iterSal
    
    %% 3.1 计算 LP 的 sinkPoint &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
    fprintf('\n compute sink point for GP ...\n')
    regionDist = IF_LP_Infor.regionDist;
    regionSal  = IF_LP_Infor.regionSal; clear IF_LP_Infor 
    IF_lp = computeIF(regionDist,regionSal,spNum,bgRatio,IFmodel);
    clear regionSal regionDist
    
    %% 4 global propagation &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
    fprintf('\n global propagation ...\n')
    [GP_Img,GP_sal] = globalPropagation(regionFea_mappedA,LP_sal,LP_Img,pixelList,...
                                        LP_compactness,tmpSPinfor,[r,c],IF_lp);    

    %% 5 save & clear
    iterSal_Img = GP_Img;
%     iterSal = GP_sal;
    clear LP_sal GP_sal regionFea_mappedA regionFea_mapping 
end

%% B: 分配最终结果 &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
fprintf('\n assigenment the last result ...')
% [iterSal_img, ~]  = CreateImageFromSPs(iterSal, tmpSPinfor.pixelList, r, c, true);
switch GPsign
    case 'YES'
         iterSal_Img = graphCut_Refine(cur_image,iterSal_Img); 
         TPSPSAL     = iterSal_Img;
    case 'NO'
         TPSPSAL     = iterSal_Img;  
end
TPSPSAL = normalizeSal(guidedfilter(TPSPSAL,TPSPSAL,6,0.1));

TPSPSALRegionSal = cell(length(CURINFOR.fea),1);% 各尺度下的结果
for ss=1:length(CURINFOR.fea)
    tmpSPinfor   = CURINFOR.spinfor{ss,1};
    TPSPSALRegionSal{ss,1} = ...
        computeRegionSal(TPSPSAL,tmpSPinfor.pixelList);% 各尺度下的区域显著性值
    clear tmpSPinfor
end

clear CURINFOR IMSAL_TPSAL1 param cur_image GPsign

end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 子函数区域  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 0 计算sinkpoints &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
function IF = computeIF(regionDist,regionSal,spNum,bgRatio,model)        
% SCB = regionDist.*regionSal;
% SCB = normalizeSal(SCB);
% SCB = computeCompactness(regionSal,regionDist);
SCB = regionDist.*(regionSal/sum(regionSal));
switch model
    case '1'
        deltas = ones(spNum,1);
        IFNUM = round(bgRatio*spNum);% 一幅图像大约有1/5的区域为背景区域
        [value,index] = sort(SCB);
        IF_index = index(1:IFNUM);
        deltas(IF_index,1) = 0;
        IF = deltas;
        clear delyas IFNUM SCB value index IF_index
        
    case '2'
        IF  = double(SCB>0);% 0 sink points; 1 other points
        clear SCB 
end

clear regionDist regionSal spNum bgRatio model
end

% % 1 计算物体重心 &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
% function [xcenter,ycenter] = computeObjectCenter(refImage)
% [r,c] = size(refImage);
% row = 1:r;
% row = row';
% col = 1:c;
% XX = repmat(row,1,c).*refImage;
% YY = repmat(col,r,1).*refImage;
% xcenter = sum(XX(:))/sum(refImage(:));% row
% ycenter = sum(YY(:))/sum(refImage(:));% column
% clear refImage
% end

% 2 根据初始融合结果，计算各尺度下的显著性值 &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
function regionSal = computeRegionSal(refImage,pixelList)
regionSal = zeros(length(pixelList),1);

for i=1:length(pixelList)
    regionSal(i,1) = mean(refImage(pixelList{i,1}));
end
regionSal = normalizeSal(regionSal);

clear refImage pixelList
end
% 
% % 3 计算各区域距离中心的距离 &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
% % 归一化 2016.11.10 14:46PM
% function dist = computeRegion2CenterDist(regionCenter,objectCenter,imageSize)
% sigmaRatio = 0.25;
% rcenter = objectCenter(1);
% ccenter = objectCenter(2); 
% r = imageSize(1);
% c = imageSize(2); 
% dist = zeros(size(regionCenter,1),1);
% sigma=[r*sigmaRatio c*sigmaRatio];
% 
% for i=1:length(regionCenter)
%     tmpRegionCenter = regionCenter(i,:);
%     xx = tmpRegionCenter(2);
%     yy = tmpRegionCenter(1);
%     dist(i,1) = exp(-(xx-rcenter)^2/(2*sigma(1)^2)-(yy-ccenter)^2/(2*sigma(2)^2));
% end
% 
% dist = normalizeSal(dist);
% % dist = dist/sum(dist);% 归一化 2016.11.10 14:46PM
% 
% clear regionCenter objectCenter imageSize
% end

% 6. 全局传播(去除空间距离，因为特征中包含了位置信息) &&&&&&&&&&&&&&&&&&&&&&&&
% 去除自身 2016.11.09  13:35PM
% 引入 IF， sinkpoints  2016.11.10 14:58PM
% regionFea_mappedA,LP_sal,LP_Img,pixelList
function [result_Img,result_sal] = ...
    globalPropagation(regionFea,LP_sal,LP_Img,pixelList,...
                      LP_compactness,tmpSPinfor,imgsize,IF_lp)
r = imgsize(1);
c = imgsize(2);
spaSigma = 0.25;
spNum = tmpSPinfor.spNum;

% propagate ------------------
%    kdNum = size(tmpfea,1);
    knn=round(size(regionFea,1)*1/15);
    kdtree = vl_kdtreebuild(regionFea');% 输入 feaDim*sampleNum
    [indexs, distance] = vl_kdtreequery(kdtree,regionFea',regionFea', 'NumNeighbors', knn) ;
    distance1 = distance(2:end,:);% 舍弃第一行，自身尔；(knn-1)*sampleNum
    indexs1 = indexs(2:end,:);

%     meanDist = (repmat(mean(distance1),[(knn-1),1])+eps);
%     alpha = 2./meanDist;
    alpha = 1/mean(distance1(:));
    dist = exp(-alpha*distance1);
%     posWeight = Dist2WeightMatrix(tmpSPinfor.posDistM, spaSigma);
%     [spNum,~]=size(posWeight);
%      posWeight(1:spNum+1:end) = 0;
%      cor_posWeight=zeros(knn-1,spNum);
%      for k=1:spNum
%          cor_posWeight(:,k)=posWeight(indexs1(:,k),k);
%      end    
%      dist=dist.*cor_posWeight;

     WIJ = dist./(repmat(sum(dist),[(knn-1),1])+eps);
     WIJ = WIJ.*IF_lp(indexs1);
     
%      WIJ = WIJ.*repmat(IF_lp,[1,spNum]);% 剔除 sinkpoints % WRONG!!!
%      dist = dist.*repmat(IF_lp,[1,spNum]);% 剔除 sinkpoints
%      WIJ  = dist./(repmat(sum(dist),[(knn),1])+eps);
     

%     dist = distance1./(repmat(sum(distance1),[(knn-1),1])+eps);
%     result = sum(LP_sal(indexs1).*dist);
    GP_sal = sum(LP_sal(indexs1).*WIJ);
    GP_sal = normalizeSal(GP_sal);
    GP_sal = GP_sal';

% fusion -----------------------------
    [GP_Img, ~]  = CreateImageFromSPs(GP_sal, tmpSPinfor.pixelList, r, c, true);figure,imshow(GP_Img,[]),title('gp')
    [rcenter_GP,ccenter_GP] = computeObjectCenter(GP_Img);
    regionCenter = tmpSPinfor.region_center;
    regionDist_GP = ...
        computeRegion2CenterDist(regionCenter,[rcenter_GP,ccenter_GP],[r,c]);
    GP_compactness = computeCompactness(GP_sal,regionDist_GP);
    wGP   = GP_compactness/(GP_compactness + LP_compactness);
    wLP   = LP_compactness/(GP_compactness + LP_compactness);

% RESULT ------------------------------
result_Img = normalizeSal(wGP*GP_Img + wLP*LP_Img);figure,imshow(result_Img,[]),title('gpfusion')
result_sal = computeRegionSal(result_Img,pixelList);
%     result_sal = normalizeSal(wGP*GP_sal + wLP*LP_sal);
    
    clear GP_Img GP_sal regionDist_GP GP_compactness
    
clear meanDist alpha WIJ
clear indexs distance indexs1 distance1
clear LP_sal regionFea kdtree
end

% 7 局部传播 2016.11.09  13:42PM &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
% adjmatrix 2-hop 2016.11.10 10:40AM
% 引入sinkpoint IF_init 2016.11.10 15:31PM
% 于像素级图像进行融合，然后计算区域显著性值 2016.11.13  22:32PM
function [result_Img,result_sal,result_compactness,IF_LP_Infor] = ...
    localPropagation(regionFea,regionSal,initSal_img,pixelList,...
                     init_compactness,tmpSPinfor,imgsize,IF_init)
% initial ---------------------
adjcMatrix = tmpSPinfor.adjcMatrix;
spNum = size(adjcMatrix,1);
r = imgsize(1);
c = imgsize(2);
 
    adjcMatrix1 = adjcMatrix;
    %link neighbor's neighbor 2-hop 2016.11.10
%     bdIds = GetBndPatchIds(tmpSPinfor.idxcurrImage);
%     adjcMatrix1(bdIds, bdIds) = 1;
    adjcMatrix1 = (adjcMatrix1 * adjcMatrix1 + adjcMatrix1) > 0;
    adjcMatrix1 = double(adjcMatrix1);
    
    adjcMatrix1(adjcMatrix1~=0) = 1;
    adjcMatrix1(1:spNum+1:end) = 0;
    adjmat = full(adjcMatrix1); % 仅仅是邻域   
    clear adjcMatrix1 adjcMatrix

% propagate -------------------
    LP_Sal = zeros(spNum,1);
    for ii=1:spNum
        tmpAdj = adjmat(ii,:);
        adjIndex = find(tmpAdj==1);
        
        tmpFea = regionFea(ii,:);
        tmpFea_adj = regionFea(adjIndex,:);
        feadiff = repmat(tmpFea,[length(adjIndex),1]) - tmpFea_adj;
        feadiff = sqrt(sum(feadiff.*feadiff,2));% size(adjsetfea,1)*1
        alpha_fea = 2/(mean(feadiff(:))+eps);
        feadiff = exp(-alpha_fea*feadiff);
               
        SAL_adj = regionSal(adjIndex,:);
        wij = feadiff/(sum(feadiff(:))+eps);
        
        % 引入 sinkPoints 概念 2016.11.10 14:40PM
        tmpIF = IF_init(adjIndex,:);
        wij   = wij.*tmpIF;
        
        LP_Sal(ii,1) = sum(wij.*SAL_adj);
        
        clear SAL_adj wij tmpFea_adj feadiff
    end
    LP_Sal  = normalizeSal(LP_Sal);
    % fusion -----------------------------
    [LP_Img, ~]  = CreateImageFromSPs(LP_Sal, tmpSPinfor.pixelList, r, c, true);figure,imshow(LP_Img,[]),title('lp')
    [rcenter_LP,ccenter_LP] = computeObjectCenter(LP_Img);% 物体中心
    regionCenter = tmpSPinfor.region_center;
    regionDist_LP = ...
        computeRegion2CenterDist(regionCenter,[rcenter_LP,ccenter_LP],[r,c]);
    compactness_LP = computeCompactness(LP_Sal,regionDist_LP);
%     compactness_LP = sum((LP_Sal/sum(LP_Sal(:))).*regionDist_LP);
    wlp = compactness_LP/(compactness_LP+init_compactness);
    winit = init_compactness/(compactness_LP+init_compactness);

    % RESULT ------------------------------
    result_Img = normalizeSal(wlp*LP_Img + winit*initSal_img);figure,imshow(result_Img,[]),title('lpfusion')
    result_sal = computeRegionSal(result_Img,pixelList);
%     result_sal = normalizeSal(wlp*LP_Sal + winit*regionSal);
%     [result_Img, ~]  = CreateImageFromSPs(result_sal, tmpSPinfor.pixelList, r, c, true);
    [rcenter_result,ccenter_result] = computeObjectCenter(result_Img);
    result_regionDist = ...
        computeRegion2CenterDist(regionCenter,[rcenter_result,ccenter_result],[r,c]);
%     result_compactness = sum(result_sal.*result_regionDist);
    result_compactness = computeCompactness(result_sal,result_regionDist);
    
    % 用于后续计算 LP 的 IF 2016.11.10 14:52PM
    IF_LP_Infor.regionDist = result_regionDist;
    IF_LP_Infor.regionSal  = result_sal;
        
    clear regionDist_LP LP_Sal
    
    % clear variables
    clear result_regionDist tmpSPinfor imgsize
    clear adjcMatrix regionFea regionSal init_compactness 

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % 4 关联阵
% function W = SetSmoothnessMatrix(colDistM, adjcMatrix_nn, theta)
% allDists = colDistM(adjcMatrix_nn > 0);
% maxVal = max(allDists);
% minVal = min(allDists);
% 
% colDistM(adjcMatrix_nn == 0) = Inf;
% colDistM = (colDistM - minVal) / (maxVal - minVal + eps);
% W = exp(-colDistM * theta);
% end
% 
% % 5 2-hop & bb
% function adjcMatrix = LinkNNAndBoundary2(adjcMatrix, bdIds)
% %link boundary SPs
% adjcMatrix(bdIds, bdIds) = 1;
% 
% %link neighbor's neighbor
% adjcMatrix = (adjcMatrix * adjcMatrix + adjcMatrix) > 0;
% adjcMatrix = double(adjcMatrix);
% 
% spNum = size(adjcMatrix, 1);
% adjcMatrix(1:spNum+1:end) = 0;  %diagnal elements set to be zero
% end
