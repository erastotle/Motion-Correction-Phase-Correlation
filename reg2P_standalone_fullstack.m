function data=reg2P_standalone_fullstack(data,batch_size,n_iter,bidi,n_ch,whichch)
%reg2P_standalone_fullstack(data,batch_size,n_iter,bidi,n_ch,whichch)
%data - X by Y by (C*T) frame stack
%batch_size - # of frames to process at one time on one computing core (default: 500)
%n_iter - # of times to repeat motion correction (default: 1)
%bidi - whether to correct for bidirectional scanning (default: false)
%n_ch - number of channels
%whichch - which channel to motion correct based on
%
%Based on solution from Suite2p Matlab version, now made as a standable
%implementation
%https://github.com/cortex-lab/Suite2P
%
%Please cite the original authors
%
%This implementation uses the parallel processing toolbox and has two
%advancements over the original suite2p scripts: 1. sub-pixel registration,
%2. correcting for bidirectional scanning, accounting for differences in
%offset along the x-axis
%
%J.M.Stujenske, April 2023

if nargin <4 || isempty(bidi)
    bidi=false;
end
if nargin<2 || isempty(batch_size)
    batch_size=500;
end
if nargin<3 || isempty(n_iter)
    n_iter=1;
end
if ischar(data)
    data=bigread4(data);
end
[Ly,Lx,nFrames]=size(data);
nreps=ceil(nFrames/batch_size);
if nFrames==nreps*batch_size
    data_cell=mat2cell(data,Ly,Lx,batch_size*ones(1,nreps));
else
    data_cell=mat2cell(data,Ly,Lx,[batch_size*ones(1,nreps-1) mod(nFrames,batch_size)]);
end
in=squeeze(cellfun(@isempty,data_cell));
data_cell(in)=[];
mimg=gen_template(data(:,:,whichch:n_ch:end),min(1000,nFrames));
if bidi
% [col_shift] = correct_bidirectional_offset(data,100);
% mimg=apply_col_shift(mimg,col_shift);
[mimg]=correct_bidi_across_x(mimg,1,1);
    parfor rep=1:nreps
%         data_cell{rep}=apply_col_shift(data_cell{rep},col_shift);
          data_cell{rep}=correct_bidi_across_x(data_cell{rep},n_ch,whichch);
    end
end
% dreg=zeros(Ly,Lx,nFrames,'single');
% dims=size(data2);
% options_rigid = NoRMCorreSetParms('d1',size(data2,1),'d2',size(data2,2),'bin_width',200,'max_shift',15,'us_fac',50,'init_batch',200);
% options_nonrigid = NoRMCorreSetParms('d1',dims(1),'d2',dims(2),'grid_size',[64,64],'mot_uf',4,'bin_width',800,'max_shift',[2 2],'max_dev',[50 50],'us_fac',50,'init_batch',100,'shifts_method','cubic');
dreg=cell(nreps,1);
for iter=1:n_iter
    parfor rep=1:nreps
%         frames=1+batch_size*(rep-1):min(batch_size*rep,nFrames);
    % temp=reg2P_standalone(data2(:,:,frames),mimg,false);toc;
        dreg{rep}=reg2P_standalone(data_cell{rep},mimg,false,[32 1],n_ch,whichch);
    % dreg(:,:,frames)=normcorre_batch(data2(:,:,frames),options_nonrigid);
    end
    data=cat(3,dreg{:});
end
end

function out=apply_col_shift(in,col_shift)
[Ly,Lx,nFrames]=size(in);
d_s=imresize(in,[Ly Lx*10]);
d_s(2:2:end,max(1,1-col_shift*10):min(Lx*10,Lx*10-col_shift*10),:)=d_s(2:2:end,max(1,1+col_shift*10):min(Lx*10,Lx*10+col_shift*10),:);
if col_shift<0
d_s(2:2:end,1:1-col_shift*10,:)=repmat(d_s(2:2:end,1,:),[1,1-col_shift*10 1]);
else
d_s(2:2:end,Lx*10-col_shift*10:end,:)=repmat(d_s(2:2:end,Lx*10-col_shift*10,:),[1,1+col_shift*10 1]);
end

out=imresize(d_s,[Ly Lx]);
end