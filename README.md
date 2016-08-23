# VNC 用户体验优化

背景介绍：使用 VNC 连接到虚拟机时，存在如下等几种情况，影响用户的使用体验：

1. 当存在较大的网络时延，移动鼠标时，用户会看到cursor有拖影的现象
2. 由于虚拟机本身的配置，导致 VNC 中的 cursor 和虚拟机中的 cursor，两者之间始终存在一个固定的位移

本文的目的旨在研究如何优化上述第一种现象的用户体验

## 优化思路

Linux 下隐藏虚拟机中的 mouse cursor，有几种方式：

1. 安装透明的鼠标 cursor主题。
2. 对于虚拟机QEMU，使用如下的 
      >usbdevice='tablet' 
  
      命令行参数，使虚拟机的机器成为一个使用touch screen的设备
3. 基于 X Window 的 Linux 系统，X Server 启动时隐藏鼠标是它的原生功能，只需要增加一项启动参数: nocursor。

方案1）经过测试，发现效果并不完美。桌面上的Windows有一个继承关系，最下面的桌面叫做root window，鼠标cursor在某一个Window中的样式，默认继承自parent window，但是app也可以使用其自己的主题样式，这种情况下，方案1)不能满足需求。

方案2) 未测试成功，而且其实现是基于QEMU，对其他虚拟机工具无效。

方案3) 经过测试，效果完美，但Xorg Server自从版本1.7(2009/10 release)才开始原生支持隐藏cursor功能，这意味着，在较老的发行版或不是基于X Windows的发行版上，此方案将无法工作。但绝大多数的发行版都是基于X Windows。

三种方案比较，方案3)在适用范围，实际效果上，是最好的。

## 方案实施
基于Xorg Server的方案实施，有几个难点：

1. 不同发行版的Xorg Server的可执行文件名不同
2. 以怎样的方式做到批量apply到虚拟机系统中
3. 如何做到仅仅给Xorg Server的启动参数仅增加一项，而不影响系统的其他部分

经过观察不同的发行版，决定以脚本的形式实施。

## 使用限制
1. 脚本基于bash 4.3 开发，其他的shell和bash版本未测试。若系统默认shell不是bash，需要使用 "bash ./script" 方式执行该脚本.
   已发现部分脚本语法不能被dash完美支持(ubuntu 15.04上的默认shell)
2. 脚本假设Xorg Server的可执行文件名字包含："Xorg" 或 "X"。其他的样式尚未支持，但扩展也很容易。
   或者支持以入参的方式传入(需要继续开发)
3. 本脚本仅支持基于X Windows(Xorg Server)的，且版本>=1.7的Linux发行版, 且必须在X启动的情况下执行该脚本。

## 测试
在qemu/KVM上测试过，包括：Fedora21(Gnome3), Fedora23workstation, kubuntu16.04-desktop(KDE), ubuntu 15.04，Suse Linux Enterprise 12。完整测试case如下：

<table>
    <tr>
    <th>有Cursor的Case</th>
    <th>Expected Result</th> 
    <th>Actual Result</th> 
    </tr>
    
    <tr>
    <td>1. 执行脚本Hack X</td>
    <td>成功</td>
    <td>ok</td>
    </tr>

    <tr>
    <td>2. 基于1，重复执行脚本Hack X</td>
    <td>失败</td>
    <td>ok</td>
    </tr>

    <tr>
    <td>3. 基于2，执行脚本revert</td>
    <td>成功</td>
    <td>ok</td>
    </tr>

    <tr>
    <td>4. 基于3，重复revert</td>
    <td>失败</td>
    <td>ok</td>
    </tr>

    <tr>
    <td>5. 基于4，再次执行脚本hack X</td>
    <td>成功</td>
    <td>ok</td>
    </tr>

    <tr>
    <td>6. 基于5，重复Hack X</td>
    <td>失败</td>
    <td>ok</td>
    </tr>

    <tr>
    <td>7. 没有hack时，直接revert</td>
    <td>失败</td>
    <td>ok</td>
    </tr>

    <tr>
    <td>8. 基于 7 重复revert</td>
    <td>失败</td>
    <td>ok</td>
    </tr>
</table>
 
<table>
    <tr>
    <th>无Cursor的Case</th>
    <th>Expected Result</th> 
    <th>Actual Result</th> 
    </tr>
    
    <tr>
    <td>1. 执行脚本hack X</td>
    <td>失败</td>
    <td>ok</td>
    </tr>

    <tr>
    <td>2. 基于1，重复执行脚本Hack X</td>
    <td>失败</td>
    <td>ok</td>
    </tr>

    <tr>
    <td>3. 基于2，执行脚本revert</td>
    <td>成功</td>
    <td>ok</td>
    </tr>

    <tr>
    <td>4. 基于3，重复revert</td>
    <td>失败</td>
    <td>ok</td>
    </tr>

    <tr>
    <td>5. 基于4，执行脚本hack X</td>
    <td>成功</td>
    <td>ok</td>
    </tr>

    <tr>
    <td>6. 基于5，重复Hack X</td>
    <td>失败</td>
    <td>ok</td>
    </tr>

    <tr>
    <td>7. 基于6，revert</td>
    <td>成功</td>
    <td>ok</td>
    </tr> 
</table>

## Reference
Xorg Server 版本/发布时间 对照

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
