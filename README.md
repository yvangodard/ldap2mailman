LDAP2Mailman
============

Présentation
------------

Cet outil est destiné à assurer la synchronisation des adresses emails d'un groupe LDAP (branche) avec une liste Mailman.
La liste Mailman doit être préalablement créée sous Mailman avant d'utiliser cet outil.

Pour une aide complète, installer le script et lancez le :

    ./ldap2mailman.sh help


Bug report
-------------

Si vous voulez me faire remonter un bug : [ouvrir un bug](https://github.com/ygodard/ldap2mailman/issues).


Installation
---------

Pour installer cet outil, depuis votre terminal :

	git clone https://github.com/yvangodard/ldap2mailman.git ; 
	sudo chmod -R 750 ldap2mailman


License
-------

Ce script ldap2mailman.sh de [Yvan GODARD](http://www.yvangodard.me) est mis à disposition selon les termes de la licence Creative Commons 4.0 BY NC SA (Attribution - Pas d’Utilisation Commerciale - Partage dans les Mêmes Conditions).

<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0"><img alt="Licence Creative Commons" style="border-width:0" src="http://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png" /></a>


Limitations
-----------

THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS "AS IS" AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE REGENTS AND CONTRIBUTORS BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.