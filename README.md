# 使用限制
---
1. 本脚本基于bash 4.3 开发，其他版本的shell和bash版本未测试[1]。若默认shell不是bash，请使用 "bash ./script" 方式执行该脚本
   [1] 已发现部分脚本语法不能被dash完美支持(ubuntu上的默认shell)

2. 本脚本假设：linux机器上的X server的文件名包含"Xorg" 或者 仅仅 “X” 字样。实际观察发现：Fedora21, RHCE7, Kubuntu16.04-desktop, archlinux
   上，其名字包含"Xorg"，ubuntu 15.04 上是 "X" 。若还有其他情况，将名字放入脚本中pattern数组中即可

3. 本脚本仅支持基于X Windows(Xorg Server)，且 版本>=1.7的Linux发行版, 且必须在图形界面启动的情况执行该脚本[2]
   [2]： suse 11 的Xorg server版本为 1.6.5(2009-10 release)，不满足条件，不支持

4. To be fulfill.

# 测试
1. 仅在qemu/KVM上测试过，包括Fedora21(Gnome3), Fedora23workstation, kubuntu16.04-desktop(KDE), ubuntu 15.04，Suse Linux Enterprise 12,
   其中Fedora21/ubuntu 15.04通过完整测试(详见下面case list)，其他仅通过基本功能(hack&revert)测试.

说明：期望结果包括：正确的输出信息，以及脚本执行后的输出产物

case list

一. 有cursor场景                    期望结果      实际结果

1. 执行脚本Hack X                     成功            ok
2. 基于1，重复执行脚本Hack X          失败            ok
3. 基于1，执行脚本revert              成功            ok
4. 基于3，重复revert                  失败            ok
5. 基于3，再次执行脚本hack X          成功            ok
6，基于5，重复Hack X                  失败            ok

7. 没有hack直接revert                 失败            ok
8. 基于 6 重复revert                  失败            ok

二. 无cursor场景(即已Hacked)

1. 执行脚本hack X                     失败            ok
2. 基于1， 重复hack                   失败            ok

3. 执行脚本revert                     成功            ok
4. 基于3 重复 revert                  失败            ok
5. 基于3，Hack X                      成功            ok
6. 基于5，重复hack                    失败            ok
7. 基于6，revert                      成功            ok

Reference: Xorg Server 版本/发布时间 对照

Version 	Date

1.0 	    21 December 2005

1.1 	    22 May 2006

1.2 	    22 January 2007

1.3 	    19 April 2007

1.4 	    6 September 2007

1.5 	    3 September 2008

1.6 	    25 February 2009

1.7 	    1 October 2009

1.8 	    2 April 2010

1.9 	    20 August 2010

1.10 	    25 February 2011

1.11 	    26 August 2011

1.12 	    4 March 2012

1.13 	    5 September 2012

1.14 	    5 March 2013

1.15 	    27 December 2013

1.16 	    17 July 2014

1.17 	    4 February 2015

1.18 	    9 November 2015

1.19 	    N/A
